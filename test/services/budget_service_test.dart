import 'package:budget_app/data/repository.dart';
import 'package:budget_app/models/allocation.dart';
import 'package:budget_app/models/budget_category.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/services/budget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryRepository repository;
  late BudgetService service;
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);

  setUp(() async {
    repository = MemoryRepository();
    service = BudgetService(repository);
    await repository.upsertCategory(
      const BudgetCategory(id: 'c-food', name: '伙食', monthlyLimit: 8000),
    );
    await repository.upsertCategory(
      const BudgetCategory(id: 'c-fun', name: '娛樂', monthlyLimit: 3000),
    );
  });

  group('記帳', () {
    test('記收入：開啟規劃時回傳 needsAllocation=true', () async {
      final needs = await service.addTransaction(
        type: TransactionType.income,
        amount: 40000,
        note: '薪水',
      );
      expect(needs, isTrue);
      expect(service.incomeOfMonth(thisMonth), 40000);
    });

    test('記收入：關閉規劃時回傳 false', () async {
      await repository.setBudgetPlanningEnabled(false);
      final needs = await service.addTransaction(
        type: TransactionType.income,
        amount: 10000,
      );
      expect(needs, isFalse);
    });

    test('記支出：需要類別', () async {
      await service.addTransaction(
        type: TransactionType.expense,
        amount: 500,
        categoryId: 'c-fun',
        note: '會員',
      );
      expect(service.expenseOfMonth(thisMonth), 500);
      expect(service.spentOnCategory('c-fun', thisMonth), 500);
    });

    test('負數金額會轉為正數', () async {
      await service.addTransaction(
        type: TransactionType.expense,
        amount: -300,
        categoryId: 'c-food',
      );
      expect(service.expenseOfMonth(thisMonth), 300);
    });

    test('拒絕 0、NaN 與無限大金額，且不寫入交易', () async {
      for (final amount in [
        0.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        await expectLater(
          service.addTransaction(type: TransactionType.income, amount: amount),
          throwsA(isA<ArgumentError>()),
        );
      }
      expect(repository.getTransactions(), isEmpty);
    });

    test('支出未提供有效類別時拋出明確例外，且不寫入交易', () async {
      for (final categoryId in <String?>[null, '', '   ']) {
        await expectLater(
          service.addTransaction(
            type: TransactionType.expense,
            amount: 100,
            categoryId: categoryId,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
      expect(repository.getTransactions(), isEmpty);
    });

    test('跨月隔離：上個月交易不影響本月', () async {
      await repository.addTransaction(
        Transaction(
          id: 'tx-old',
          type: TransactionType.expense,
          amount: 9999,
          categoryId: 'c-food',
          date: lastMonth,
        ),
      );
      expect(service.expenseOfMonth(thisMonth), 0);
      expect(service.spentOnCategory('c-food', thisMonth), 0);
    });
  });

  group('收入分配（核心特色）', () {
    test('分配後待分配池正確減少', () async {
      await service.addTransaction(
        type: TransactionType.income,
        amount: 40000,
        note: '薪水',
      );
      final transaction = repository.getTransactions().firstWhere(
        (transaction) => transaction.type == TransactionType.income,
      );

      expect(service.unassignedOfMonth(thisMonth), 40000);

      await service.saveAllocation(transaction.id, const [
        Allocation(categoryId: 'c-food', amount: 8000),
        Allocation(categoryId: 'c-fun', amount: 3000),
      ]);

      expect(service.allocatedOfMonth(thisMonth), 11000);
      expect(service.unassignedOfMonth(thisMonth), 29000);
      expect(service.allocatedToCategory('c-food', thisMonth), 8000);
    });

    test('部分分配允許，未分配留在池中', () async {
      await service.addTransaction(type: TransactionType.income, amount: 40000);
      final transaction = repository.getTransactions().firstWhere(
        (transaction) => transaction.type == TransactionType.income,
      );

      await service.saveAllocation(transaction.id, const [
        Allocation(categoryId: 'c-food', amount: 12000),
      ]);

      expect(service.unassignedOfMonth(thisMonth), 28000);
      expect(service.remainingForIncome(transaction.id), 28000);
      expect(service.isIncomeFullyAllocated(transaction.id), isFalse);
      expect(service.pendingIncomesOfMonth(thisMonth), contains(transaction));
    });

    test('只有完全分配的收入才算完成', () async {
      await service.addTransaction(type: TransactionType.income, amount: 10000);
      final transaction = repository.getTransactions().single;

      await service.saveAllocation(transaction.id, const [
        Allocation(categoryId: 'c-food', amount: 10000),
      ]);

      expect(service.remainingForIncome(transaction.id), 0);
      expect(service.isIncomeFullyAllocated(transaction.id), isTrue);
      expect(service.pendingIncomesOfMonth(thisMonth), isEmpty);
    });

    test('拒絕儲存完全空的分配', () async {
      await service.addTransaction(type: TransactionType.income, amount: 10000);
      final transaction = repository.getTransactions().single;

      await expectLater(
        service.saveAllocation(transaction.id, const []),
        throwsA(isA<ArgumentError>()),
      );
      expect(repository.getIncomeAllocations(), isEmpty);
    });

    test('可安全查找非 controller 當月的收入', () async {
      final transaction = Transaction(
        id: 'cross-month-income',
        type: TransactionType.income,
        amount: 5000,
        date: lastMonth,
      );
      await repository.addTransaction(transaction);

      expect(service.findIncomeById(transaction.id), same(transaction));
      expect(service.findIncomeById('missing'), isNull);
    });

    test('isValidAllocation：總和不可超過收入', () async {
      await service.addTransaction(type: TransactionType.income, amount: 40000);
      final transaction = repository.getTransactions().firstWhere(
        (transaction) => transaction.type == TransactionType.income,
      );

      expect(
        service.isValidAllocation(transaction.id, const [
          Allocation(categoryId: 'c-food', amount: 25000),
          Allocation(categoryId: 'c-fun', amount: 20000),
        ]),
        isFalse,
      );
      expect(
        service.isValidAllocation(transaction.id, const [
          Allocation(categoryId: 'c-food', amount: 25000),
          Allocation(categoryId: 'c-fun', amount: 15000),
        ]),
        isTrue,
      );
    });

    test('重複分配同筆收入會覆蓋', () async {
      await service.addTransaction(type: TransactionType.income, amount: 10000);
      final transaction = repository.getTransactions().firstWhere(
        (transaction) => transaction.type == TransactionType.income,
      );

      await service.saveAllocation(transaction.id, const [
        Allocation(categoryId: 'c-food', amount: 6000),
      ]);
      await service.saveAllocation(transaction.id, const [
        Allocation(categoryId: 'c-food', amount: 4000),
        Allocation(categoryId: 'c-fun', amount: 6000),
      ]);

      expect(service.allocatedOfMonth(thisMonth), 10000);
      expect(service.allocatedToCategory('c-food', thisMonth), 4000);
      expect(service.allocatedToCategory('c-fun', thisMonth), 6000);
    });
  });

  group('類別餘額', () {
    test('餘額公式：上限 + 分配 − 支出', () async {
      await service.addTransaction(type: TransactionType.income, amount: 20000);
      final transaction = repository.getTransactions().firstWhere(
        (transaction) => transaction.type == TransactionType.income,
      );
      await service.saveAllocation(transaction.id, const [
        Allocation(categoryId: 'c-food', amount: 8000),
      ]);
      await service.addTransaction(
        type: TransactionType.expense,
        amount: 3000,
        categoryId: 'c-food',
      );

      final stats = service.categoryStats(thisMonth);
      final food = stats.firstWhere(
        (runningTotal) => runningTotal.category.id == 'c-food',
      );
      // 上限 8000 + 分配 8000 − 支出 3000 = 13000
      expect(food.remaining, 13000);
      expect(food.spent, 3000);
      expect(food.allocated, 8000);
    });

    test('超支顯示負數餘額', () async {
      await repository.addTransaction(
        Transaction(
          id: 'tx-x',
          type: TransactionType.expense,
          amount: 9000,
          categoryId: 'c-fun',
          date: now,
        ),
      );
      final stats = service.categoryStats(thisMonth);
      final fun = stats.firstWhere(
        (runningTotal) => runningTotal.category.id == 'c-fun',
      );
      expect(fun.remaining, -6000); // 3000 − 9000
    });

    test('usageRatio 有上限時介於 0~1', () async {
      await repository.addTransaction(
        Transaction(
          id: 'tx-y',
          type: TransactionType.expense,
          amount: 4000,
          categoryId: 'c-food',
          date: now,
        ),
      );
      final stats = service.categoryStats(thisMonth);
      final food = stats.firstWhere(
        (runningTotal) => runningTotal.category.id == 'c-food',
      );
      expect(food.usageRatio, closeTo(0.5, 0.001)); // 4000/8000
    });
  });

  group('類別刪除完整性', () {
    test('service 拒絕刪除仍被交易引用的類別並回傳領域錯誤', () async {
      await repository.addTransaction(
        Transaction(
          id: 'food-expense',
          type: TransactionType.expense,
          amount: 200,
          categoryId: 'c-food',
          date: now,
        ),
      );

      await expectLater(
        service.removeCategory('c-food'),
        throwsA(
          isA<CategoryInUseException>().having(
            (removalConflict) => removalConflict.referencedByTransaction,
            'referencedByTransaction',
            isTrue,
          ),
        ),
      );
      expect(
        repository.getCategories().map((category) => category.id),
        contains('c-food'),
      );
    });

    test('service 拒絕刪除仍被 allocation 引用的類別', () async {
      await repository.saveIncomeAllocation(
        const IncomeAllocation(
          transactionId: 'salary-income',
          allocations: [Allocation(categoryId: 'c-fun', amount: 500)],
        ),
      );

      await expectLater(
        service.removeCategory('c-fun'),
        throwsA(
          isA<CategoryInUseException>().having(
            (removalConflict) => removalConflict.referencedByAllocation,
            'referencedByAllocation',
            isTrue,
          ),
        ),
      );
    });
  });

  group('序列化', () {
    test('Transaction JSON round-trip', () {
      final transaction = Transaction(
        id: 't1',
        type: TransactionType.income,
        amount: 123.45,
        categoryId: 'c-food',
        date: DateTime(2026, 8, 7),
        note: '測試',
      );
      expect(Transaction.fromJson(transaction.toJson()).amount, 123.45);
      expect(
        Transaction.fromJson(transaction.toJson()).type,
        TransactionType.income,
      );
    });

    test('BudgetCategory JSON round-trip', () {
      const budgetController = BudgetCategory(
        id: 'c1',
        name: '房租',
        monthlyLimit: 12000,
        colorValue: 0xFF112233,
      );
      final restored = BudgetCategory.fromJson(budgetController.toJson());
      expect(restored.name, '房租');
      expect(restored.monthlyLimit, 12000);
      expect(restored.colorValue, 0xFF112233);
    });

    test('IncomeAllocation JSON round-trip', () {
      const allocation = IncomeAllocation(
        transactionId: 'tx1',
        allocations: [
          Allocation(categoryId: 'c1', amount: 500),
          Allocation(categoryId: 'c2', amount: 1500),
        ],
      );
      final restored = IncomeAllocation.fromJson(allocation.toJson());
      expect(restored.totalAllocated, 2000);
      expect(restored.allocations.length, 2);
    });
  });
}
