import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repository.dart';
import 'models/allocation.dart';
import 'models/budget_category.dart';
import 'models/member.dart';
import 'models/shared_transaction.dart';
import 'models/theme_preset.dart';
import 'models/transaction.dart';
import 'screens/root_screen.dart';
import 'services/budget_service.dart';
import 'services/shared_ledger_service.dart';
import 'theme/app_theme.dart';

extension<ElementType> on Iterable<ElementType> {
  ElementType? get lastOrNull {
    var result = null as ElementType?;
    for (final currentItem in this) {
      result = currentItem;
    }
    return result;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final repository = SharedPrefsRepository(preferences);
  runApp(
    BudgetApp(
      controller: BudgetController(
        BudgetService(repository),
        SharedLedgerService(repository),
      ),
    ),
  );
}

/// 全域狀態控制器：UI 透過它與 [BudgetService] 互動
class BudgetController extends ChangeNotifier {
  final BudgetService service;
  final SharedLedgerService shared;
  DateTime _month = DateTime.now();
  ThemeMode _themeMode = ThemeMode.system;

  BudgetController(this.service, this.shared) {
    _themeMode = _themeFromName(service.repository.getThemeModeName());
  }

  ThemeMode get themeMode => _themeMode;

  static ThemeMode _themeFromName(String name) => switch (name) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await service.repository.setThemeModeName(mode.name);
    notifyListeners();
  }

  // ── 主題系統（付費解鎖） ──

  ThemePreset get themePreset =>
      themePresetById(service.repository.getThemeId());
  Set<String> get unlockedThemeIds =>
      service.repository.getUnlockedThemeIds().toSet();

  bool isThemeUnlocked(ThemePreset preset) =>
      !preset.premium || unlockedThemeIds.contains(preset.id);

  Future<void> setTheme(String id) async {
    await service.repository.setThemeId(id);
    notifyListeners();
  }

  /// 解鎖付費主題（真實 App 中此處串接 IAP 金流；目前為示範模式）
  Future<void> unlockTheme(String id) async {
    await service.repository.addUnlockedTheme(id);
    await service.repository.setThemeId(id);
    notifyListeners();
  }

  // ── Pro 會員（付費功能分層） ──

  bool get isPro => service.repository.isPro();

  /// 免費版預算類別上限；Pro 無限
  static const int freeCategoryLimit = 3;

  bool get canAddCategory =>
      isPro || service.repository.getCategories().length < freeCategoryLimit;

  /// 升級 Pro（真實 App 中串接 IAP；目前為示範模式，一次性 NT$590）
  Future<void> upgradeToPro() async {
    await service.repository.setPro(true);
    notifyListeners();
  }

  DateTime get month => _month;

  void setMonth(DateTime member) {
    _month = DateTime(member.year, member.month);
    notifyListeners();
  }

  void prevMonth() => setMonth(DateTime(_month.year, _month.month - 1));
  void nextMonth() => setMonth(DateTime(_month.year, _month.month + 1));

  List<Transaction> get transactions => service.transactionsOfMonth(_month);
  List<BudgetCategory> get categories => service.repository.getCategories();
  double get income => service.incomeOfMonth(_month);
  double get expense => service.expenseOfMonth(_month);
  double get balance => service.balanceOfMonth(_month);
  double get unassigned => service.unassignedOfMonth(_month);
  bool get planningEnabled => service.repository.isBudgetPlanningEnabled();

  Future<Transaction?> addTransaction({
    required TransactionType type,
    required double amount,
    String? categoryId,
    DateTime? date,
    String note = '',
  }) async {
    await service.addTransaction(
      type: type,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    notifyListeners();
    return service.repository.getTransactions().lastOrNull;
  }

  Future<void> saveAllocation(
    String transactionId,
    List<Allocation> allocation,
  ) async {
    await service.saveAllocation(transactionId, allocation);
    notifyListeners();
  }

  Future<void> upsertCategory(BudgetCategory budgetController) async {
    await service.repository.upsertCategory(budgetController);
    notifyListeners();
  }

  Future<void> removeCategory(String id) async {
    await service.removeCategory(id);
    notifyListeners();
  }

  /// 類別拖拽排序（依使用者偏好）
  Future<void> reorderCategories(List<BudgetCategory> ordered) async {
    await service.repository.reorderCategories(
      ordered.map((currentItem) => currentItem.id).toList(),
    );
    notifyListeners();
  }

  Future<void> setPlanningEnabled(bool selectedValue) async {
    await service.repository.setBudgetPlanningEnabled(selectedValue);
    notifyListeners();
  }

  // ── 共同帳本 ──

  List<Member> get members => shared.getMembers();
  List<SharedTransaction> get sharedTransactions =>
      shared.getTransactions(_month);
  double get sharedIncome => shared.totalShownIncome();
  double get sharedExpense => shared.totalSharedExpense(_month);
  double get sharedBalance => shared.sharedBalance(_month);

  Map<String, double> splitOf(SharedTransaction transaction) =>
      shared.splitOf(transaction, members);

  double memberShareTotal(String memberId) =>
      shared.memberShareTotal(memberId, _month);

  double memberBalance(String memberId) =>
      shared.memberBalance(memberId, _month);

  Future<void> upsertMember(Member member) async {
    await shared.upsertMember(member);
    notifyListeners();
  }

  Future<void> removeMember(String id) async {
    await shared.removeMember(id);
    notifyListeners();
  }

  Future<void> addSharedTransaction(SharedTransaction transaction) async {
    final frozenTransaction = shared.freezeSplit(transaction);
    await service.repository.addSharedTransaction(frozenTransaction);

    // 同步到個人帳本：共同支出且開啟同步時，依分攤結果寫入各成員個人支出
    if (!frozenTransaction.isIncome && frozenTransaction.syncToPersonal) {
      final split = shared.splitOf(frozenTransaction, members);
      final catName = frozenTransaction.categoryName.isEmpty
          ? '共同支出'
          : frozenTransaction.categoryName;
      for (final entry in split.entries) {
        final amount = entry.value;
        if (amount <= 0) continue;
        final catId = await service.ensureCategoryByName(catName);
        await service.repository.addTransaction(
          Transaction(
            id: 'tx-${frozenTransaction.id}-${entry.key}',
            type: TransactionType.expense,
            amount: amount,
            categoryId: catId,
            date: frozenTransaction.date,
            note: '共同支出：$catName',
            sourceSharedTransactionId: frozenTransaction.id,
          ),
        );
      }
    }
    notifyListeners();
  }

  Future<void> removeSharedTransaction(String id) async {
    await service.repository.removeSharedTransaction(id);
    notifyListeners();
  }
}

class BudgetApp extends StatelessWidget {
  final BudgetController controller;

  const BudgetApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<BudgetController>(
        builder: (context, budgetController, _) => MaterialApp(
          title: '零基記帳',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(budgetController.themePreset),
          darkTheme: buildDarkTheme(budgetController.themePreset),
          themeMode: budgetController.themeMode,
          home: const RootScreen(),
        ),
      ),
    );
  }
}
