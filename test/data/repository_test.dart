import 'package:budget_app/data/repository.dart';
import 'package:budget_app/models/allocation.dart';
import 'package:budget_app/models/budget_category.dart';
import 'package:budget_app/models/member.dart';
import 'package:budget_app/models/shared_transaction.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoryRepository', () {
    testIncompleteReorderPreservesRemainingCategories(
      () async => MemoryRepository(),
    );
    testRemovingIncomeAlsoRemovesAllocation(() async => MemoryRepository());
    testRemovingSharedTransactionRemovesPersonalMirrors(
      () async => MemoryRepository(),
    );
    testReferencedCategoryCannotBeRemoved(() async => MemoryRepository());
    testLegacySharedTransactionIsFrozenOnAdd();
  });

  group('SharedPrefsRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testIncompleteReorderPreservesRemainingCategories(() async {
      return SharedPrefsRepository(await SharedPreferences.getInstance());
    });
    testRemovingIncomeAlsoRemovesAllocation(() async {
      return SharedPrefsRepository(await SharedPreferences.getInstance());
    });
    testRemovingSharedTransactionRemovesPersonalMirrors(() async {
      return SharedPrefsRepository(await SharedPreferences.getInstance());
    });
    testReferencedCategoryCannotBeRemoved(() async {
      return SharedPrefsRepository(await SharedPreferences.getInstance());
    });
    test('legacy JSON migration 固化一次、可重開且保持交易筆數與金額', () async {
      SharedPreferences.setMockInitialValues({
        'members':
            '[{"id":"member-a","name":"甲","shownIncome":300,"actualIncome":300},'
            '{"id":"member-b","name":"乙","shownIncome":700,"actualIncome":700}]',
        'shared_transactions':
            '[{"id":"legacy-shared","amount":1000,"date":"2026-08-12T00:00:00.000",'
            '"splitMode":"byIncomeRatio"}]',
      });
      final preferences = await SharedPreferences.getInstance();
      final firstRepository = SharedPrefsRepository(preferences);

      final migrated = firstRepository.getSharedTransactions();
      expect(migrated, hasLength(1));
      expect(migrated.single.amount, 1000);
      expect(migrated.single.splitSnapshot, {'member-a': 300, 'member-b': 700});

      await firstRepository.upsertMember(
        const Member(
          id: 'member-a',
          name: '甲',
          shownIncome: 1000,
          actualIncome: 1000,
        ),
      );
      await firstRepository.removeMember('member-b');
      final reopenedRepository = SharedPrefsRepository(preferences);
      final reopened = reopenedRepository.getSharedTransactions();

      expect(reopened, hasLength(1));
      expect(reopened.single.amount, 1000);
      expect(reopened.single.splitSnapshot, {'member-a': 300, 'member-b': 700});
    });
  });
}

void testRemovingSharedTransactionRemovesPersonalMirrors(
  Future<BudgetRepository> Function() createRepository,
) {
  test('刪除已同步共同交易時同步刪除所有個人鏡像支出', () async {
    final repository = await createRepository();
    await repository.addSharedTransaction(
      SharedTransaction(
        id: 'abc',
        amount: 1200,
        date: DateTime(2026, 8, 12),
        syncToPersonal: true,
      ),
    );
    await repository.addTransaction(
      Transaction(
        id: 'personal-mirror-for-abc',
        type: TransactionType.expense,
        amount: 600,
        categoryId: 'rent',
        date: DateTime(2026, 8, 12),
        sourceSharedTransactionId: 'abc',
      ),
    );
    await repository.addTransaction(
      Transaction(
        id: 'personal-mirror-for-abc-x',
        type: TransactionType.expense,
        amount: 75,
        categoryId: 'rent',
        date: DateTime(2026, 8, 12),
        sourceSharedTransactionId: 'abc-x',
      ),
    );
    await repository.addTransaction(
      Transaction(
        id: 'unrelated-transaction',
        type: TransactionType.expense,
        amount: 50,
        categoryId: 'rent',
        date: DateTime(2026, 8, 12),
      ),
    );

    await repository.removeSharedTransaction('abc');

    expect(repository.getSharedTransactions(), isEmpty);
    expect(repository.getTransactions().map((transaction) => transaction.id), [
      'personal-mirror-for-abc-x',
      'unrelated-transaction',
    ]);
  });

  test('未同步共同交易刪除時不碰同前綴個人交易', () async {
    final repository = await createRepository();
    await repository.addSharedTransaction(
      SharedTransaction(
        id: 'shared-manual',
        amount: 100,
        date: DateTime(2026, 8, 12),
        syncToPersonal: false,
      ),
    );
    await repository.addTransaction(
      Transaction(
        id: 'tx-shared-manual-imported',
        type: TransactionType.expense,
        amount: 100,
        categoryId: 'miscellaneous',
        date: DateTime(2026, 8, 12),
      ),
    );

    await repository.removeSharedTransaction('shared-manual');

    expect(repository.getTransactions(), hasLength(1));
  });
}

void testLegacySharedTransactionIsFrozenOnAdd() {
  test('MemoryRepository add 時固化 legacy transaction snapshot', () async {
    final repository = MemoryRepository();
    await repository.upsertMember(
      const Member(id: 'member-a', name: '甲', shownIncome: 300),
    );
    await repository.upsertMember(
      const Member(id: 'member-b', name: '乙', shownIncome: 700),
    );

    await repository.addSharedTransaction(
      SharedTransaction(
        id: 'legacy-memory',
        amount: 1000,
        date: DateTime(2026, 8, 12),
        splitMode: SplitMode.byIncomeRatio,
      ),
    );
    await repository.removeMember('member-b');
    await repository.upsertMember(
      const Member(id: 'member-a', name: '甲', shownIncome: 1000),
    );

    expect(repository.getSharedTransactions().single.splitSnapshot, {
      'member-a': 300,
      'member-b': 700,
    });
  });
}

void testReferencedCategoryCannotBeRemoved(
  Future<BudgetRepository> Function() createRepository,
) {
  test('仍被支出交易引用的類別拒絕刪除', () async {
    final repository = await createRepository();
    await repository.upsertCategory(
      const BudgetCategory(id: 'food-category', name: '伙食'),
    );
    await repository.addTransaction(
      Transaction(
        id: 'lunch-transaction',
        type: TransactionType.expense,
        amount: 120,
        categoryId: 'food-category',
        date: DateTime(2026, 8, 12),
      ),
    );

    expect(
      () => repository.removeCategory('food-category'),
      throwsA(isA<CategoryInUseException>()),
    );
    expect(repository.getCategories(), hasLength(1));
  });

  test('仍被收入 allocation 引用的類別拒絕刪除', () async {
    final repository = await createRepository();
    await repository.upsertCategory(
      const BudgetCategory(id: 'saving-category', name: '儲蓄'),
    );
    await repository.saveIncomeAllocation(
      const IncomeAllocation(
        transactionId: 'salary-transaction',
        allocations: [Allocation(categoryId: 'saving-category', amount: 500)],
      ),
    );

    expect(
      () => repository.removeCategory('saving-category'),
      throwsA(isA<CategoryInUseException>()),
    );
    expect(repository.getCategories(), hasLength(1));
  });
}

void testIncompleteReorderPreservesRemainingCategories(
  Future<BudgetRepository> Function() createRepository,
) {
  test('不完整 IDs 只重排已列類別，未列類別依原順序保留', () async {
    final repository = await createRepository();
    for (final categoryId in ['a', 'b', 'c', 'd']) {
      await repository.upsertCategory(
        BudgetCategory(id: categoryId, name: categoryId),
      );
    }

    await repository.reorderCategories(['c', 'a']);

    expect(repository.getCategories().map((category) => category.id), [
      'c',
      'a',
      'b',
      'd',
    ]);
  });
}

void testRemovingIncomeAlsoRemovesAllocation(
  Future<BudgetRepository> Function() createRepository,
) {
  test('刪除收入交易時同步刪除其 allocation', () async {
    final repository = await createRepository();
    await repository.addTransaction(
      Transaction(
        id: 'income-1',
        type: TransactionType.income,
        amount: 1000,
        date: DateTime(2026, 8, 12),
      ),
    );
    await repository.saveIncomeAllocation(
      const IncomeAllocation(
        transactionId: 'income-1',
        allocations: [Allocation(categoryId: 'food', amount: 500)],
      ),
    );

    await repository.removeTransaction('income-1');

    expect(repository.getTransactions(), isEmpty);
    expect(repository.getIncomeAllocations(), isEmpty);
  });
}
