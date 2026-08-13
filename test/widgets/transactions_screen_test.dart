import 'package:budget_app/data/repository.dart';
import 'package:budget_app/main.dart';
import 'package:budget_app/models/budget_category.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/screens/transactions_screen.dart';
import 'package:budget_app/services/budget_service.dart';
import 'package:budget_app/services/shared_ledger_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('無類別支出與收入都顯示在全部交易', (tester) async {
    final repository = MemoryRepository();
    await repository.upsertCategory(
      BudgetCategory(id: 'c1', name: '伙食', monthlyLimit: 5000),
    );
    repository.addTransaction(
      Transaction(
        id: 't1',
        type: TransactionType.expense,
        amount: 150,
        date: DateTime(2026, 8, 1),
        note: '沒選類別的支出',
      ),
    );
    repository.addTransaction(
      Transaction(
        id: 't2',
        type: TransactionType.expense,
        amount: 200,
        categoryId: 'c1',
        date: DateTime(2026, 8, 2),
        note: '有類別的支出',
      ),
    );
    repository.addTransaction(
      Transaction(
        id: 't3',
        type: TransactionType.income,
        amount: 50000,
        date: DateTime(2026, 8, 3),
        note: '薪水',
      ),
    );

    final budgetController = BudgetController(
      BudgetService(repository),
      SharedLedgerService(repository),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: budgetController,
          child: const TransactionsScreen(),
        ),
      ),
    );

    // 三筆都必須顯示（含未選類別的支出；備註顯示在副標題）
    expect(find.textContaining('沒選類別'), findsOneWidget);
    expect(find.textContaining('有類別'), findsOneWidget);
    expect(find.textContaining('薪水'), findsOneWidget);
    // 未選類別的支出金額也要出現
    expect(find.textContaining('150'), findsWidgets);
  });
}
