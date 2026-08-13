import 'package:budget_app/data/repository.dart';
import 'package:budget_app/main.dart';
import 'package:budget_app/models/allocation.dart';
import 'package:budget_app/models/budget_category.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/screens/add_transaction_screen.dart';
import 'package:budget_app/screens/allocation_screen.dart';
import 'package:budget_app/screens/budget_settings_screen.dart';
import 'package:budget_app/screens/home_screen.dart';
import 'package:budget_app/screens/root_screen.dart';
import 'package:budget_app/services/budget_service.dart';
import 'package:budget_app/services/shared_ledger_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

BudgetController controllerFor(MemoryRepository repository) => BudgetController(
  BudgetService(repository),
  SharedLedgerService(repository),
);

Widget testApp(BudgetController controller, Widget home) =>
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(home: home),
    );

void main() {
  test('Donut 使用總可用預算為分母，0 分母為 0%', () {
    expect(budgetUsagePercent(250, 1000), 25);
    expect(budgetUsagePercent(250, 0), 0);
  });

  testWidgets('跨月收入可安全進入分配頁', (tester) async {
    final repository = MemoryRepository();
    await repository.upsertCategory(
      const BudgetCategory(id: 'food', name: '伙食'),
    );
    await repository.addTransaction(
      Transaction(
        id: 'old-income',
        type: TransactionType.income,
        amount: 5000,
        date: DateTime(2025, 1, 1),
        note: '舊月收入',
      ),
    );
    final controller = controllerFor(repository)..setMonth(DateTime(2026, 8));

    await tester.pumpWidget(
      testApp(
        controller,
        const AllocationScreen(
          mode: AllocationMode.income,
          incomeTransactionId: 'old-income',
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('舊月收入'), findsOneWidget);
    expect(find.textContaining('5,000'), findsWidgets);
  });

  testWidgets('指定收入不存在時顯示可恢復狀態', (tester) async {
    final repository = MemoryRepository();
    final controller = controllerFor(repository);

    await tester.pumpWidget(
      testApp(
        controller,
        const AllocationScreen(
          mode: AllocationMode.income,
          incomeTransactionId: 'missing',
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('找不到這筆收入'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
  });

  testWidgets('空分配無法儲存，部分分配可再進入修改', (tester) async {
    final now = DateTime.now();
    final repository = MemoryRepository();
    await repository.upsertCategory(
      const BudgetCategory(id: 'food', name: '伙食'),
    );
    final income = Transaction(
      id: 'income',
      type: TransactionType.income,
      amount: 10000,
      date: now,
    );
    await repository.addTransaction(income);
    final controller = controllerFor(repository);

    await tester.pumpWidget(
      testApp(
        controller,
        const AllocationScreen(
          mode: AllocationMode.income,
          incomeTransactionId: 'income',
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '完成規劃'))
          .onPressed,
      isNull,
    );

    await controller.saveAllocation('income', const [
      Allocation(categoryId: 'food', amount: 3000),
    ]);
    await tester.pumpWidget(
      testApp(controller, HomeScreen(onOpenDrawer: () {})),
    );
    await tester.pump();
    await tester.tap(find.textContaining('待規劃'));
    await tester.pumpAndSettle();

    expect(find.byType(AllocationScreen), findsOneWidget);
    expect(find.textContaining('剩餘'), findsWidgets);
    expect(find.widgetWithText(TextField, '3000'), findsOneWidget);
  });

  testWidgets('monthlyLimit=0 的類別不顯示超支警告', (tester) async {
    final repository = MemoryRepository();
    await repository.upsertCategory(
      const BudgetCategory(id: 'free', name: '無上限', monthlyLimit: 0),
    );
    final controller = controllerFor(repository);

    await tester.pumpWidget(testApp(controller, const AddTransactionScreen()));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.tap(find.text('無上限'));
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('記錄支出'));
    await tester.pump();

    expect(find.text('已記錄 ✓'), findsOneWidget);
    expect(find.textContaining('已超支'), findsNothing);

    await tester.pumpWidget(
      testApp(controller, HomeScreen(onOpenDrawer: () {})),
    );
    await tester.pump();
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.textContaining('超 100'), findsNothing);
  });

  testWidgets('主頁啟動不會被隱藏的快速記帳搶鍵盤', (tester) async {
    final repository = MemoryRepository();
    final controller = controllerFor(repository);

    await tester.pumpWidget(testApp(controller, const RootScreen()));
    await tester.pumpAndSettle();

    expect(find.text('本月可用餘額'), findsOneWidget);
    expect(find.byType(AddTransactionScreen), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('刪除仍被交易引用的類別時保留類別並顯示領域訊息', (tester) async {
    final repository = MemoryRepository();
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
    final controller = controllerFor(repository);

    await tester.pumpWidget(testApp(controller, const BudgetSettingsScreen()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(repository.getCategories(), hasLength(1));
    expect(find.textContaining('仍有交易或收入分配使用'), findsOneWidget);
  });
}
