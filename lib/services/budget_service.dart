import 'dart:math';

import '../data/repository.dart';
import '../models/allocation.dart';
import '../models/budget_category.dart';
import '../models/transaction.dart';

/// 類別在某月的統計
class CategoryMonthStats {
  final BudgetCategory category;
  final double allocated; // 本月分配給該類別的收入
  final double spent; // 本月支出
  final double limit; // 每月上限（0 = 無上限）

  CategoryMonthStats({
    required this.category,
    required this.allocated,
    required this.spent,
    required this.limit,
  });

  /// 剩餘可花：上限 + 分配 − 支出
  double get remaining => limit + allocated - spent;

  /// 預算使用率（有上限時）
  double? get usageRatio =>
      limit > 0 ? ((allocated + limit - remaining) / limit).clamp(0, 1) : null;

  /// 已用金額 = 分配 + 上限 − 剩餘
  double get used => limit + allocated - remaining;
}

/// 核心商業邏輯：記帳 + 零基預算分配
class BudgetService {
  final BudgetRepository repository;

  BudgetService(this.repository);

  // ── 記帳 ────────────────────────────────────────────

  /// 新增交易。收入回傳 true 表示「可進入分配引導」。
  Future<bool> addTransaction({
    required TransactionType type,
    required double amount,
    String? categoryId,
    DateTime? date,
    String note = '',
  }) async {
    if (!amount.isFinite || amount == 0) {
      throw ArgumentError.value(amount, 'amount', '交易金額必須是非 0 的有限數值');
    }
    if (type == TransactionType.expense &&
        (categoryId == null || categoryId.trim().isEmpty)) {
      throw ArgumentError.value(categoryId, 'categoryId', '支出交易必須指定類別');
    }
    final transaction = Transaction(
      id: _newId('tx'),
      type: type,
      amount: amount.abs(),
      categoryId: categoryId,
      date: date ?? DateTime.now(),
      note: note,
    );
    await repository.addTransaction(transaction);
    return type == TransactionType.income &&
        repository.isBudgetPlanningEnabled();
  }

  // ── 查詢（本月為準）────────────────────────────────

  List<Transaction> transactionsOfMonth(DateTime month) => repository
      .getTransactions()
      .where((transaction) => _sameMonth(transaction.date, month))
      .toList();

  double incomeOfMonth(DateTime month) => transactionsOfMonth(month)
      .where((transaction) => transaction.type == TransactionType.income)
      .fold(
        0,
        (runningTotal, transaction) => runningTotal + transaction.amount,
      );

  double expenseOfMonth(DateTime month) => transactionsOfMonth(month)
      .where((transaction) => transaction.type == TransactionType.expense)
      .fold(
        0,
        (runningTotal, transaction) => runningTotal + transaction.amount,
      );

  double balanceOfMonth(DateTime month) =>
      incomeOfMonth(month) - expenseOfMonth(month);

  // ── 分配（核心特色）────────────────────────────────

  /// 本月所有收入分配總額
  double allocatedOfMonth(DateTime month) {
    final txIds = transactionsOfMonth(month)
        .where((transaction) => transaction.type == TransactionType.income)
        .map((transaction) => transaction.id)
        .toSet();
    return repository
        .getIncomeAllocations()
        .where((allocation) => txIds.contains(allocation.transactionId))
        .fold(
          0,
          (runningTotal, allocation) =>
              runningTotal + allocation.totalAllocated,
        );
  }

  /// 待分配池 = 本月收入 − 已分配
  double unassignedOfMonth(DateTime month) =>
      incomeOfMonth(month) - allocatedOfMonth(month);

  /// 指定類別本月分配收入
  double allocatedToCategory(String categoryId, DateTime month) {
    final txIds = transactionsOfMonth(month)
        .where((transaction) => transaction.type == TransactionType.income)
        .map((transaction) => transaction.id)
        .toSet();
    double sum = 0;
    for (final allocation in repository.getIncomeAllocations()) {
      if (!txIds.contains(allocation.transactionId)) continue;
      for (final allocation in allocation.allocations) {
        if (allocation.categoryId == categoryId) sum += allocation.amount;
      }
    }
    return sum;
  }

  /// 指定類別本月支出
  double spentOnCategory(String categoryId, DateTime month) =>
      transactionsOfMonth(month)
          .where(
            (transaction) =>
                transaction.type == TransactionType.expense &&
                transaction.categoryId == categoryId,
          )
          .fold(
            0,
            (runningTotal, transaction) => runningTotal + transaction.amount,
          );

  /// 所有類別本月統計
  List<CategoryMonthStats> categoryStats(DateTime month) {
    return repository.getCategories().map((budgetController) {
      return CategoryMonthStats(
        category: budgetController,
        allocated: allocatedToCategory(budgetController.id, month),
        spent: spentOnCategory(budgetController.id, month),
        limit: budgetController.monthlyLimit,
      );
    }).toList()..sort(
      (allocation, rightValue) =>
          rightValue.allocated.compareTo(allocation.allocated),
    );
  }

  /// 從全部交易安全查找收入，不受 controller 目前月份影響。
  Transaction? findIncomeById(String transactionId) => repository
      .getTransactions()
      .where(
        (transaction) =>
            transaction.id == transactionId &&
            transaction.type == TransactionType.income,
      )
      .firstOrNull;

  IncomeAllocation? allocationForIncome(String transactionId) => repository
      .getIncomeAllocations()
      .where((allocation) => allocation.transactionId == transactionId)
      .firstOrNull;

  /// 單筆收入尚可分配金額。
  double remainingForIncome(String transactionId) {
    final income = findIncomeById(transactionId);
    if (income == null) return 0;
    final allocated = allocationForIncome(transactionId)?.totalAllocated ?? 0;
    return max(0, income.amount - allocated);
  }

  /// 只有收入全額分配後才算完成。
  bool isIncomeFullyAllocated(String transactionId) {
    final income = findIncomeById(transactionId);
    return income != null && remainingForIncome(transactionId) <= 1e-6;
  }

  /// 保留舊 API 名稱，語意改為「已完全分配」。
  bool isIncomeAllocated(String transactionId) =>
      isIncomeFullyAllocated(transactionId);

  List<Transaction> pendingIncomesOfMonth(DateTime month) =>
      transactionsOfMonth(month)
          .where(
            (transaction) =>
                transaction.type == TransactionType.income &&
                !isIncomeFullyAllocated(transaction.id),
          )
          .toList();

  /// 檢查分配是否有效：總和 ≤ 該筆收入
  bool isValidAllocation(String transactionId, List<Allocation> allocations) {
    final transaction = repository
        .getTransactions()
        .where(
          (transaction) =>
              transaction.id == transactionId &&
              transaction.type == TransactionType.income,
        )
        .firstOrNull;
    if (transaction == null) return false;
    final total = allocations.fold<double>(
      0,
      (runningTotal, allocation) => runningTotal + allocation.amount,
    );
    return total <= transaction.amount + 1e-6;
  }

  /// 儲存分配
  Future<void> saveAllocation(
    String transactionId,
    List<Allocation> allocations,
  ) async {
    if (allocations.isEmpty) {
      throw ArgumentError.value(allocations, 'allocations', '分配不得為空');
    }
    if (allocations.any(
      (allocation) => !allocation.amount.isFinite || allocation.amount <= 0,
    )) {
      throw ArgumentError.value(allocations, 'allocations', '分配金額必須為正數');
    }
    if (!isValidAllocation(transactionId, allocations)) {
      throw ArgumentError.value(allocations, 'allocations', '分配無效或超過收入');
    }
    await repository.saveIncomeAllocation(
      IncomeAllocation(transactionId: transactionId, allocations: allocations),
    );
  }

  // ── 工具 ────────────────────────────────────────────

  /// 依名稱尋找個人類別；找不到就自動建立（無上限）
  Future<String> ensureCategoryByName(String name) async {
    final categories = repository.getCategories();
    final existing = categories
        .where((budgetController) => budgetController.name == name)
        .firstOrNull;
    if (existing != null) return existing.id;
    final newCat = BudgetCategory(
      id: 'cat-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    await repository.upsertCategory(newCat);
    return newCat.id;
  }

  /// 僅在沒有交易或收入分配引用時刪除類別。
  Future<void> removeCategory(String categoryId) =>
      repository.removeCategory(categoryId);

  bool _sameMonth(DateTime allocation, DateTime rightValue) =>
      allocation.year == rightValue.year &&
      allocation.month == rightValue.month;

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';
}

extension<ElementType> on Iterable<ElementType> {
  ElementType? get firstOrNull {
    final elementIterator = iterator;
    return elementIterator.moveNext() ? elementIterator.current : null;
  }
}
