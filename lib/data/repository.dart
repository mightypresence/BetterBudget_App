import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/allocation.dart';
import '../models/budget_category.dart';
import '../models/member.dart';
import '../models/shared_transaction.dart';
import '../models/transaction.dart';
import '../services/shared_transaction_split_service.dart';

/// 類別仍被交易或收入分配引用，因此不能安全刪除。
class CategoryInUseException implements Exception {
  final String categoryId;
  final bool referencedByTransaction;
  final bool referencedByAllocation;

  const CategoryInUseException({
    required this.categoryId,
    required this.referencedByTransaction,
    required this.referencedByAllocation,
  });

  String get userMessage => '此類別仍有交易或收入分配使用，請先移除相關紀錄後再刪除。';

  @override
  String toString() => 'CategoryInUseException: $userMessage';
}

CategoryInUseException? categoryRemovalConflict(
  String categoryId,
  List<Transaction> transactions,
  List<IncomeAllocation> incomeAllocations,
) {
  final referencedByTransaction = transactions.any(
    (transaction) => transaction.categoryId == categoryId,
  );
  final referencedByAllocation = incomeAllocations.any(
    (incomeAllocation) => incomeAllocation.allocations.any(
      (allocation) => allocation.categoryId == categoryId,
    ),
  );
  if (!referencedByTransaction && !referencedByAllocation) return null;
  return CategoryInUseException(
    categoryId: categoryId,
    referencedByTransaction: referencedByTransaction,
    referencedByAllocation: referencedByAllocation,
  );
}

/// 資料存取抽象：App 用 SharedPreferences，測試用記憶體實作
abstract class BudgetRepository {
  List<Transaction> getTransactions();
  Future<void> addTransaction(Transaction transaction);
  Future<void> removeTransaction(String id);

  List<BudgetCategory> getCategories();
  Future<void> upsertCategory(BudgetCategory category);
  Future<void> removeCategory(String id);

  /// 依使用者拖拽順序重新排列類別（傳入完整的新順序 id 清單）
  Future<void> reorderCategories(List<String> orderedIds);

  List<IncomeAllocation> getIncomeAllocations();
  Future<void> saveIncomeAllocation(IncomeAllocation allocation);

  bool isBudgetPlanningEnabled();
  Future<void> setBudgetPlanningEnabled(bool enabled);

  String getThemeModeName();
  Future<void> setThemeModeName(String name);

  String getThemeId();
  Future<void> setThemeId(String id);

  List<String> getUnlockedThemeIds();
  Future<void> addUnlockedTheme(String id);

  bool isPro();
  Future<void> setPro(bool value);

  // ── 共同帳本 ──
  List<Member> getMembers();
  Future<void> upsertMember(Member member);
  Future<void> removeMember(String id);

  List<SharedTransaction> getSharedTransactions();
  Future<void> addSharedTransaction(SharedTransaction transaction);
  Future<void> removeSharedTransaction(String id);
}

/// 測試用記憶體實作
class MemoryRepository implements BudgetRepository {
  static const _sharedTransactionSplitService = SharedTransactionSplitService();
  final List<Transaction> _transactions = [];
  final List<BudgetCategory> _categories = [];
  final List<IncomeAllocation> _allocations = [];
  bool _planningEnabled = true;
  String _themeModeName = 'system';
  String _themeId = 'forest';
  final List<String> _unlockedThemes = [];
  bool _isPro = false;

  @override
  List<Transaction> getTransactions() => List.unmodifiable(_transactions);

  @override
  Future<void> addTransaction(Transaction transaction) async =>
      _transactions.add(transaction);

  @override
  Future<void> removeTransaction(String id) async {
    _transactions.removeWhere((transaction) => transaction.id == id);
    _allocations.removeWhere((allocation) => allocation.transactionId == id);
  }

  @override
  List<BudgetCategory> getCategories() => List.unmodifiable(_categories);

  @override
  Future<void> upsertCategory(BudgetCategory budgetController) async {
    final itemIndex = _categories.indexWhere(
      (currentItem) => currentItem.id == budgetController.id,
    );
    if (itemIndex >= 0) {
      _categories[itemIndex] = budgetController;
    } else {
      _categories.add(budgetController);
    }
  }

  @override
  Future<void> removeCategory(String id) async {
    final removalConflict = categoryRemovalConflict(
      id,
      _transactions,
      _allocations,
    );
    if (removalConflict != null) throw removalConflict;
    _categories.removeWhere((category) => category.id == id);
  }

  @override
  Future<void> reorderCategories(List<String> orderedIds) async {
    final byId = {
      for (final currentItem in _categories) currentItem.id: currentItem,
    };
    final reorderedIds = <String>{};
    final ordered = <BudgetCategory>[];
    for (final id in orderedIds) {
      final category = byId[id];
      if (category != null && reorderedIds.add(id)) ordered.add(category);
    }
    ordered.addAll(
      _categories.where((category) => !reorderedIds.contains(category.id)),
    );
    _categories
      ..clear()
      ..addAll(ordered);
  }

  @override
  List<IncomeAllocation> getIncomeAllocations() =>
      List.unmodifiable(_allocations);

  @override
  Future<void> saveIncomeAllocation(IncomeAllocation allocation) async {
    _allocations.removeWhere(
      (currentItem) => currentItem.transactionId == allocation.transactionId,
    );
    _allocations.add(allocation);
  }

  @override
  bool isBudgetPlanningEnabled() => _planningEnabled;

  @override
  Future<void> setBudgetPlanningEnabled(bool enabled) async =>
      _planningEnabled = enabled;

  @override
  String getThemeModeName() => _themeModeName;

  @override
  Future<void> setThemeModeName(String name) async => _themeModeName = name;

  @override
  String getThemeId() => _themeId;

  @override
  Future<void> setThemeId(String id) async => _themeId = id;

  @override
  List<String> getUnlockedThemeIds() => List.unmodifiable(_unlockedThemes);

  @override
  Future<void> addUnlockedTheme(String id) async {
    if (!_unlockedThemes.contains(id)) _unlockedThemes.add(id);
  }

  @override
  bool isPro() => _isPro;

  @override
  Future<void> setPro(bool value) async => _isPro = value;

  // ── 共同帳本 ──
  final List<Member> _members = [];
  final List<SharedTransaction> _sharedTransactions = [];

  @override
  List<Member> getMembers() => List.unmodifiable(_members);

  @override
  Future<void> upsertMember(Member member) async {
    final itemIndex = _members.indexWhere(
      (currentItem) => currentItem.id == member.id,
    );
    if (itemIndex >= 0) {
      _members[itemIndex] = member;
    } else {
      _members.add(member);
    }
  }

  @override
  Future<void> removeMember(String id) async =>
      _members.removeWhere((member) => member.id == id);

  @override
  List<SharedTransaction> getSharedTransactions() =>
      List.unmodifiable(_sharedTransactions);

  @override
  Future<void> addSharedTransaction(SharedTransaction transaction) async {
    _sharedTransactions.add(
      _sharedTransactionSplitService.freeze(transaction, _members),
    );
  }

  @override
  Future<void> removeSharedTransaction(String id) async {
    final transactionToRemove = _sharedTransactions
        .where((transaction) => transaction.id == id)
        .firstOrNull;
    _sharedTransactions.removeWhere((transaction) => transaction.id == id);
    if (transactionToRemove?.syncToPersonal ?? false) {
      final removedMirrorIds = _transactions
          .where((transaction) => transaction.sourceSharedTransactionId == id)
          .map((transaction) => transaction.id)
          .toSet();
      _transactions.removeWhere(
        (transaction) => removedMirrorIds.contains(transaction.id),
      );
      _allocations.removeWhere(
        (allocation) => removedMirrorIds.contains(allocation.transactionId),
      );
    }
  }
}

/// App 實作：SharedPreferences + JSON
class SharedPrefsRepository implements BudgetRepository {
  static const _sharedTransactionSplitService = SharedTransactionSplitService();
  static const _kTransactions = 'transactions';
  static const _kCategories = 'categories';
  static const _kAllocations = 'allocations';
  static const _kPlanning = 'budget_planning_enabled';
  static const _kMembers = 'members';
  static const _sharedTransactionsStorageKey = 'shared_transactions';
  static const _kThemeMode = 'theme_mode';
  static const _kThemeId = 'theme_id';
  static const _kUnlockedThemes = 'unlocked_themes';
  static const _kPro = 'pro_member';

  final SharedPreferences _preferences;

  SharedPrefsRepository(this._preferences);

  @override
  List<Transaction> getTransactions() {
    final raw = _preferences.getString(_kTransactions);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (currentItem) =>
              Transaction.fromJson(currentItem as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> addTransaction(Transaction transaction) async {
    final list = getTransactions()..add(transaction);
    await _preferences.setString(
      _kTransactions,
      jsonEncode(list.map((currentItem) => currentItem.toJson()).toList()),
    );
  }

  @override
  Future<void> removeTransaction(String id) async {
    final list = getTransactions()
      ..removeWhere((transaction) => transaction.id == id);
    final allocations = getIncomeAllocations()
      ..removeWhere((allocation) => allocation.transactionId == id);
    await _preferences.setString(
      _kAllocations,
      jsonEncode(
        allocations.map((currentItem) => currentItem.toJson()).toList(),
      ),
    );
    await _preferences.setString(
      _kTransactions,
      jsonEncode(list.map((currentItem) => currentItem.toJson()).toList()),
    );
  }

  @override
  List<BudgetCategory> getCategories() {
    final raw = _preferences.getString(_kCategories);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (currentItem) =>
              BudgetCategory.fromJson(currentItem as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> upsertCategory(BudgetCategory budgetController) async {
    final list = getCategories();
    final itemIndex = list.indexWhere(
      (currentItem) => currentItem.id == budgetController.id,
    );
    if (itemIndex >= 0) {
      list[itemIndex] = budgetController;
    } else {
      list.add(budgetController);
    }
    await _preferences.setString(
      _kCategories,
      jsonEncode(list.map((currentItem) => currentItem.toJson()).toList()),
    );
  }

  @override
  Future<void> removeCategory(String id) async {
    final removalConflict = categoryRemovalConflict(
      id,
      getTransactions(),
      getIncomeAllocations(),
    );
    if (removalConflict != null) throw removalConflict;
    final list = getCategories()
      ..removeWhere((budgetController) => budgetController.id == id);
    await _preferences.setString(
      _kCategories,
      jsonEncode(list.map((currentItem) => currentItem.toJson()).toList()),
    );
  }

  @override
  Future<void> reorderCategories(List<String> orderedIds) async {
    final categories = getCategories();
    final byId = {
      for (final currentItem in categories) currentItem.id: currentItem,
    };
    final reorderedIds = <String>{};
    final ordered = <BudgetCategory>[];
    for (final id in orderedIds) {
      final category = byId[id];
      if (category != null && reorderedIds.add(id)) ordered.add(category);
    }
    ordered.addAll(
      categories.where((category) => !reorderedIds.contains(category.id)),
    );
    await _preferences.setString(
      _kCategories,
      jsonEncode(ordered.map((currentItem) => currentItem.toJson()).toList()),
    );
  }

  @override
  List<IncomeAllocation> getIncomeAllocations() {
    final raw = _preferences.getString(_kAllocations);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (currentItem) =>
              IncomeAllocation.fromJson(currentItem as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> saveIncomeAllocation(IncomeAllocation allocation) async {
    final list = getIncomeAllocations()
      ..removeWhere(
        (currentItem) => currentItem.transactionId == allocation.transactionId,
      )
      ..add(allocation);
    await _preferences.setString(
      _kAllocations,
      jsonEncode(list.map((currentItem) => currentItem.toJson()).toList()),
    );
  }

  @override
  bool isBudgetPlanningEnabled() => _preferences.getBool(_kPlanning) ?? true;

  @override
  Future<void> setBudgetPlanningEnabled(bool enabled) async =>
      _preferences.setBool(_kPlanning, enabled);

  @override
  String getThemeModeName() => _preferences.getString(_kThemeMode) ?? 'system';

  @override
  Future<void> setThemeModeName(String name) async =>
      _preferences.setString(_kThemeMode, name);

  @override
  String getThemeId() => _preferences.getString(_kThemeId) ?? 'forest';

  @override
  Future<void> setThemeId(String id) async =>
      _preferences.setString(_kThemeId, id);

  @override
  List<String> getUnlockedThemeIds() =>
      _preferences.getStringList(_kUnlockedThemes) ?? [];

  @override
  Future<void> addUnlockedTheme(String id) async {
    final list = getUnlockedThemeIds();
    if (!list.contains(id)) {
      list.add(id);
      await _preferences.setStringList(_kUnlockedThemes, list);
    }
  }

  @override
  bool isPro() => _preferences.getBool(_kPro) ?? false;

  @override
  Future<void> setPro(bool value) async => _preferences.setBool(_kPro, value);

  // ── 共同帳本 ──

  @override
  List<Member> getMembers() {
    final raw = _preferences.getString(_kMembers);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (currentItem) => Member.fromJson(currentItem as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> upsertMember(Member member) async {
    final list = getMembers();
    final itemIndex = list.indexWhere(
      (currentItem) => currentItem.id == member.id,
    );
    if (itemIndex >= 0) {
      list[itemIndex] = member;
    } else {
      list.add(member);
    }
    await _preferences.setString(
      _kMembers,
      jsonEncode(list.map((currentItem) => currentItem.toJson()).toList()),
    );
  }

  @override
  Future<void> removeMember(String id) async {
    final list = getMembers()..removeWhere((member) => member.id == id);
    await _preferences.setString(
      _kMembers,
      jsonEncode(list.map((currentItem) => currentItem.toJson()).toList()),
    );
  }

  @override
  List<SharedTransaction> getSharedTransactions() {
    final raw = _preferences.getString(_sharedTransactionsStorageKey);
    if (raw == null) return [];
    final decodedTransactions = (jsonDecode(raw) as List)
        .map(
          (currentItem) =>
              SharedTransaction.fromJson(currentItem as Map<String, dynamic>),
        )
        .toList();
    if (decodedTransactions.every(
      (transaction) => transaction.splitSnapshot != null,
    )) {
      return decodedTransactions;
    }
    final migratedTransactions = _sharedTransactionSplitService
        .freezeLegacyTransactions(decodedTransactions, getMembers());
    _preferences.setString(
      _sharedTransactionsStorageKey,
      jsonEncode(
        migratedTransactions
            .map((transaction) => transaction.toJson())
            .toList(),
      ),
    );
    return migratedTransactions;
  }

  @override
  Future<void> addSharedTransaction(SharedTransaction transaction) async {
    final frozenTransaction = _sharedTransactionSplitService.freeze(
      transaction,
      getMembers(),
    );
    final list = getSharedTransactions()..add(frozenTransaction);
    await _preferences.setString(
      _sharedTransactionsStorageKey,
      jsonEncode(list.map((currentItem) => currentItem.toJson()).toList()),
    );
  }

  @override
  Future<void> removeSharedTransaction(String id) async {
    final existingTransactions = getSharedTransactions();
    final transactionToRemove = existingTransactions
        .where((transaction) => transaction.id == id)
        .firstOrNull;
    final list = existingTransactions
      ..removeWhere((transaction) => transaction.id == id);
    await _preferences.setString(
      _sharedTransactionsStorageKey,
      jsonEncode(list.map((currentItem) => currentItem.toJson()).toList()),
    );
    if (transactionToRemove?.syncToPersonal ?? false) {
      final personalTransactions = getTransactions();
      final removedMirrorIds = personalTransactions
          .where((transaction) => transaction.sourceSharedTransactionId == id)
          .map((transaction) => transaction.id)
          .toSet();
      personalTransactions.removeWhere(
        (transaction) => removedMirrorIds.contains(transaction.id),
      );
      final incomeAllocations = getIncomeAllocations()
        ..removeWhere(
          (allocation) => removedMirrorIds.contains(allocation.transactionId),
        );
      await _preferences.setString(
        _kTransactions,
        jsonEncode(
          personalTransactions
              .map((transaction) => transaction.toJson())
              .toList(),
        ),
      );
      await _preferences.setString(
        _kAllocations,
        jsonEncode(
          incomeAllocations.map((allocation) => allocation.toJson()).toList(),
        ),
      );
    }
  }
}

extension<ElementType> on Iterable<ElementType> {
  ElementType? get firstOrNull {
    final elementIterator = iterator;
    return elementIterator.moveNext() ? elementIterator.current : null;
  }
}
