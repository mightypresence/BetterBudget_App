import 'package:budget_app/data/repository.dart';
import 'package:budget_app/models/member.dart';
import 'package:budget_app/models/shared_transaction.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/services/shared_ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryRepository repository;
  late SharedLedgerService service;
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);

  setUp(() async {
    repository = MemoryRepository();
    service = SharedLedgerService(repository);
    await repository.upsertMember(
      const Member(
        id: 'm-a',
        name: '小明',
        actualIncome: 33000,
        shownIncome: 33000,
      ),
    );
    await repository.upsertMember(
      const Member(
        id: 'm-b',
        name: '小美',
        actualIncome: 41000,
        shownIncome: 41000,
      ),
    );
  });

  group('帳本統計', () {
    test('總顯示收入 = 成員 shownIncome 加總', () {
      expect(service.totalShownIncome(), 74000);
    });

    test('本月共同支出與結餘', () async {
      await repository.addSharedTransaction(
        SharedTransaction(
          id: 't1',
          amount: 10000,
          categoryName: '房租',
          date: now,
          splitMode: SplitMode.equal,
        ),
      );
      expect(service.totalSharedExpense(thisMonth), 10000);
      expect(service.sharedBalance(thisMonth), 64000);
    });

    test('跨月隔離', () async {
      await repository.addSharedTransaction(
        SharedTransaction(
          id: 't-old',
          amount: 9999,
          date: DateTime(now.year, now.month - 1, 15),
          splitMode: SplitMode.equal,
        ),
      );
      expect(service.totalSharedExpense(thisMonth), 0);
    });
  });

  group('分攤計算', () {
    test('平均分攤：各半（餘數由最後一位吸收）', () {
      final split = service.splitOf(
        SharedTransaction(
          id: 't',
          amount: 10001,
          date: now,
          splitMode: SplitMode.equal,
        ),
        service.getMembers(),
      );
      expect(split['m-a']! + split['m-b']!, closeTo(10001, 0.001));
      expect(split['m-a'], 5000.5);
    });

    test('按收入比例分攤：33k:41k → 47%:53%', () {
      final split = service.splitOf(
        SharedTransaction(
          id: 't',
          amount: 7400,
          date: now,
          splitMode: SplitMode.byIncomeRatio,
        ),
        service.getMembers(),
      );
      // 33000/74000 * 7400 = 3300 ; 41000/74000*7400 = 4100
      expect(split['m-a'], closeTo(3300, 0.01));
      expect(split['m-b'], closeTo(4100, 0.01));
    });

    test('指定人付：全部由指定成員負擔', () {
      final split = service.splitOf(
        SharedTransaction(
          id: 't',
          amount: 5000,
          date: now,
          splitMode: SplitMode.byPayer,
          payerId: 'm-b',
        ),
        service.getMembers(),
      );
      expect(split['m-a'], isNull);
      expect(split['m-b'], 5000);
    });

    test('自由設定：使用自訂金額', () {
      final split = service.splitOf(
        SharedTransaction(
          id: 't',
          amount: 10000,
          date: now,
          splitMode: SplitMode.custom,
          customAmounts: {'m-a': 4000, 'm-b': 6000},
        ),
        service.getMembers(),
      );
      expect(split['m-a'], 4000);
      expect(split['m-b'], 6000);
    });

    test('收入比例：所有成員 shownIncome=0 時退回平均', () async {
      final emptyRepo = MemoryRepository();
      final emptyService = SharedLedgerService(emptyRepo);
      await emptyRepo.upsertMember(const Member(id: 'x', name: '甲'));
      await emptyRepo.upsertMember(const Member(id: 'y', name: '乙'));
      await emptyRepo.upsertMember(const Member(id: 'z', name: '丙'));
      final split = emptyService.splitOf(
        SharedTransaction(
          id: 't',
          amount: 900,
          date: now,
          splitMode: SplitMode.byIncomeRatio,
        ),
        emptyService.getMembers(),
      );
      expect(split['x'], 300);
      expect(split['y'], 300);
      expect(split['z'], 300);
    });
  });

  group('成員結餘與私房錢', () {
    test('成員結餘 = 顯示收入 − 分攤總額', () async {
      await repository.addSharedTransaction(
        SharedTransaction(
          id: 't1',
          amount: 10000,
          categoryName: '房租',
          date: now,
          splitMode: SplitMode.equal,
        ),
      );
      // 小明分攤 5000 → 結餘 28000
      expect(service.memberShareTotal('m-a', thisMonth), 5000);
      expect(service.memberBalance('m-a', thisMonth), 28000);
      expect(service.memberBalance('m-b', thisMonth), 36000);
    });

    test('私房錢 = 實際收入 − 顯示收入；分攤只看顯示收入', () async {
      await repository.upsertMember(
        const Member(
          id: 'm-c',
          name: '有私房錢的人',
          actualIncome: 50000,
          shownIncome: 40000,
        ),
      );
      final member = service.getMembers().firstWhere(
        (currentItem) => currentItem.id == 'm-c',
      );
      expect(member.privateSavings, 10000);
      // 分攤只用顯示收入 40000（非實際 50000）
      // 總顯示收入 = 33000+41000+40000 = 114000
      final split = service.splitOf(
        SharedTransaction(
          id: 't',
          amount: 1000,
          date: now,
          splitMode: SplitMode.byIncomeRatio,
        ),
        service.getMembers(),
      );
      expect(split['m-c'], closeTo(350.88, 0.01)); // 1000×40000/114000
      expect(split['m-a'], closeTo(289.47, 0.01)); // 1000×33000/114000
    });
  });

  group('序列化', () {
    test('Transaction JSON source relation round-trip 且舊 JSON 為 null', () {
      final relatedTransaction = Transaction(
        id: 'personal-mirror',
        type: TransactionType.expense,
        amount: 100,
        date: DateTime(2026, 8, 7),
        sourceSharedTransactionId: 'shared-source',
      );

      expect(
        Transaction.fromJson(
          relatedTransaction.toJson(),
        ).sourceSharedTransactionId,
        'shared-source',
      );
      expect(
        Transaction.fromJson({
          'id': 'legacy-personal',
          'type': 'expense',
          'amount': 100,
          'date': '2026-08-07T00:00:00.000',
        }).sourceSharedTransactionId,
        isNull,
      );
    });
    test('Member JSON round-trip', () {
      const member = Member(
        id: 'm1',
        name: '測試',
        actualIncome: 100,
        shownIncome: 80,
      );
      final restoredValue = Member.fromJson(member.toJson());
      expect(restoredValue.name, '測試');
      expect(restoredValue.privateSavings, 20);
    });

    test('SharedTransaction JSON round-trip', () {
      final transaction = SharedTransaction(
        id: 't1',
        amount: 500,
        categoryName: '水電',
        date: DateTime(2026, 8, 7),
        splitMode: SplitMode.custom,
        customAmounts: const {'a': 200, 'b': 300},
        splitSnapshot: const {'a': 200, 'b': 300},
      );
      final restoredValue = SharedTransaction.fromJson(transaction.toJson());
      expect(restoredValue.splitMode, SplitMode.custom);
      expect(restoredValue.customAmounts['a'], 200);
      expect(restoredValue.splitSnapshot, {'a': 200, 'b': 300});
    });

    test('舊 JSON 沒有 split snapshot 時保持向後相容並可動態 fallback', () {
      final restoredValue = SharedTransaction.fromJson({
        'id': 'legacy-transaction',
        'amount': 7400,
        'date': '2026-08-07T00:00:00.000',
        'splitMode': 'byIncomeRatio',
      });

      expect(restoredValue.splitSnapshot, isNull);
      expect(service.splitOf(restoredValue, service.getMembers()), {
        'm-a': 3300,
        'm-b': 4100,
      });
    });
  });
}
