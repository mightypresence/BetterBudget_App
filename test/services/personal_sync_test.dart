import 'package:budget_app/data/repository.dart';
import 'package:budget_app/main.dart';
import 'package:budget_app/models/budget_category.dart';
import 'package:budget_app/models/member.dart';
import 'package:budget_app/models/shared_transaction.dart';
import 'package:budget_app/services/budget_service.dart';
import 'package:budget_app/services/shared_ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 共同支出 → 個人帳本同步 的核心測試
void main() {
  late MemoryRepository repository;
  late BudgetController budgetController;
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);

  setUp(() async {
    repository = MemoryRepository();
    budgetController = BudgetController(
      BudgetService(repository),
      SharedLedgerService(repository),
    );
    await budgetController.upsertMember(
      const Member(
        id: 'm-a',
        name: '小明',
        actualIncome: 33000,
        shownIncome: 33000,
      ),
    );
    await budgetController.upsertMember(
      const Member(
        id: 'm-b',
        name: '小美',
        actualIncome: 41000,
        shownIncome: 41000,
      ),
    );
  });

  group('共同支出同步到個人帳本', () {
    test('平均分攤：個人帳本各記一筆分攤金額，類別自動建立', () async {
      await budgetController.addSharedTransaction(
        SharedTransaction(
          id: 'stx-1',
          amount: 10000,
          categoryName: '房租',
          date: now,
          splitMode: SplitMode.equal,
        ),
      );

      expect(
        budgetController.service.expenseOfMonth(thisMonth),
        10000,
      ); // 5000+5000
      // 自動建立「房租」類別
      final category = budgetController.service.repository
          .getCategories()
          .firstWhere((currentItem) => currentItem.name == '房租');
      expect(
        budgetController.service.spentOnCategory(category.id, thisMonth),
        10000,
      );
    });

    test('已有同名類別：使用既有類別並扣預算', () async {
      await budgetController.upsertCategory(
        const BudgetCategory(id: 'c-water', name: '水電', monthlyLimit: 1500),
      );
      await budgetController.addSharedTransaction(
        SharedTransaction(
          id: 'stx-2',
          amount: 1000,
          categoryName: '水電',
          date: now,
          splitMode: SplitMode.equal,
        ),
      );

      final stats = budgetController.service.categoryStats(thisMonth);
      final water = stats.firstWhere(
        (runningTotal) => runningTotal.category.id == 'c-water',
      );
      // 上限 1500 − 支出 1000 = 500
      expect(water.remaining, 500);
      expect(
        budgetController.service.repository.getCategories().length,
        1,
      ); // 沒有重複建立
    });

    test('按收入比例分攤：個人帳本金額按比例（33000:41000）', () async {
      await budgetController.addSharedTransaction(
        SharedTransaction(
          id: 'stx-3',
          amount: 7400,
          categoryName: '水電費',
          date: now,
          splitMode: SplitMode.byIncomeRatio,
        ),
      );
      // 3300 + 4100
      expect(budgetController.service.expenseOfMonth(thisMonth), 7400);
    });

    test('指定人付：只有付款人的個人帳本被記錄', () async {
      await budgetController.addSharedTransaction(
        SharedTransaction(
          id: 'stx-4',
          amount: 5000,
          categoryName: '聚餐',
          date: now,
          splitMode: SplitMode.byPayer,
          payerId: 'm-b',
        ),
      );
      expect(budgetController.service.expenseOfMonth(thisMonth), 5000);
    });

    test('關閉同步：不寫入個人帳本', () async {
      await budgetController.addSharedTransaction(
        SharedTransaction(
          id: 'stx-5',
          amount: 3000,
          categoryName: '水電',
          date: now,
          splitMode: SplitMode.equal,
          syncToPersonal: false,
        ),
      );
      expect(budgetController.service.expenseOfMonth(thisMonth), 0);
    });

    test('共同收入不寫入個人帳本支出', () async {
      await budgetController.addSharedTransaction(
        SharedTransaction(
          id: 'stx-6',
          amount: 2000,
          isIncome: true,
          categoryName: '二手賣出',
          date: now,
          splitMode: SplitMode.equal,
        ),
      );
      expect(budgetController.service.expenseOfMonth(thisMonth), 0);
    });

    test('新增時固化分攤，成員收入變更或移除後歷史結果不漂移', () async {
      await budgetController.addSharedTransaction(
        SharedTransaction(
          id: 'stable-history',
          amount: 7400,
          categoryName: '房租',
          date: now,
          splitMode: SplitMode.byIncomeRatio,
        ),
      );

      final storedTransaction = repository.getSharedTransactions().single;
      expect(storedTransaction.splitSnapshot, {'m-a': 3300, 'm-b': 4100});

      await budgetController.upsertMember(
        const Member(
          id: 'm-a',
          name: '小明',
          actualIncome: 100000,
          shownIncome: 100000,
        ),
      );
      await budgetController.removeMember('m-b');

      expect(budgetController.splitOf(storedTransaction), {
        'm-a': 3300,
        'm-b': 4100,
      });
      expect(budgetController.memberShareTotal('m-a'), 3300);
    });

    test('刪除共同交易後個人鏡像支出也消失', () async {
      await budgetController.addSharedTransaction(
        SharedTransaction(
          id: 'shared-to-delete',
          amount: 1000,
          categoryName: '水電',
          date: now,
          splitMode: SplitMode.equal,
        ),
      );
      expect(repository.getTransactions(), hasLength(2));
      expect(
        repository.getTransactions().map(
          (transaction) => transaction.sourceSharedTransactionId,
        ),
        everyElement('shared-to-delete'),
      );

      await budgetController.removeSharedTransaction('shared-to-delete');

      expect(repository.getSharedTransactions(), isEmpty);
      expect(repository.getTransactions(), isEmpty);
    });
  });
}
