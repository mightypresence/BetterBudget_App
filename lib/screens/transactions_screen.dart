import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

/// 全部交易：搜尋 + 篩選（類別/類型/金額範圍）
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  String? _categoryFilter;
  String? _typeFilter; // 'income' | 'expense' | null
  double? _minAmount;
  double? _maxAmount;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _filtered(BudgetController budgetController) {
    // 所有交易都要顯示（含未選類別的支出）；顯示與預算規劃設定無關
    final all = budgetController.service.repository.getTransactions().toList()
      ..sort(
        (allocation, rightValue) => rightValue.date.compareTo(allocation.date),
      );
    final searchQuery = _searchController.text.trim().toLowerCase();
    return all.where((transaction) {
      if (searchQuery.isNotEmpty) {
        final catName = budgetController.categories
            .where((category) => category.id == transaction.categoryId)
            .firstOrNull
            ?.name;
        final note = transaction.note.toLowerCase();
        final name = catName?.toLowerCase() ?? '';
        if (!note.contains(searchQuery) && !name.contains(searchQuery)) {
          return false;
        }
      }
      if (_categoryFilter != null &&
          transaction.categoryId != _categoryFilter) {
        return false;
      }
      if (_typeFilter == 'income' &&
          transaction.type != TransactionType.income) {
        return false;
      }
      if (_typeFilter == 'expense' &&
          transaction.type != TransactionType.expense) {
        return false;
      }
      if (_minAmount != null && transaction.amount < _minAmount!) return false;
      if (_maxAmount != null && transaction.amount > _maxAmount!) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();
    final list = _filtered(budgetController);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('全部交易')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '搜尋類別或備註…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          // 篩選列
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _typeFilter == null,
                  onSelected: (_) => setState(() => _typeFilter = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('收入'),
                  selected: _typeFilter == 'income',
                  onSelected: (_) => setState(() => _typeFilter = 'income'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('支出'),
                  selected: _typeFilter == 'expense',
                  onSelected: (_) => setState(() => _typeFilter = 'expense'),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  tooltip: '類別篩選',
                  onSelected: (selectedValue) => setState(
                    () => _categoryFilter = selectedValue == '__all'
                        ? null
                        : selectedValue,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: '__all', child: Text('所有類別')),
                    for (
                      var itemIndex = 0;
                      itemIndex < budgetController.categories.length;
                      itemIndex++
                    )
                      PopupMenuItem(
                        value: budgetController.categories[itemIndex].id,
                        child: Text(
                          budgetController.categories[itemIndex].name,
                          style: TextStyle(
                            color: AppColors.categoryColor(itemIndex),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 列表
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: scheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text('沒有符合的交易'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: list.length,
                    itemBuilder: (context, itemIndex) {
                      final transaction = list[itemIndex];
                      final catIndex = budgetController.categories.indexWhere(
                        (category) => category.id == transaction.categoryId,
                      );
                      final color =
                          transaction.categoryId != null && catIndex >= 0
                          ? AppColors.categoryColor(catIndex)
                          : scheme.primary;
                      final isIncome =
                          transaction.type == TransactionType.income;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(
                            isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: color,
                            size: 18,
                          ),
                        ),
                        title: Text(_titleOf(transaction, budgetController)),
                        subtitle: Text(
                          '${transaction.date.year}/${transaction.date.month}/${transaction.date.day}'
                          '${transaction.note.isEmpty ? '' : ' · ${transaction.note}'}',
                        ),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}${formatMoney(transaction.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isIncome ? scheme.primary : scheme.error,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _titleOf(Transaction transaction, BudgetController budgetController) {
    if (transaction.type == TransactionType.income) return '收入';
    final category = budgetController.categories
        .where((currentItem) => currentItem.id == transaction.categoryId)
        .firstOrNull;
    return category?.name ?? '支出';
  }
}

extension<ElementType> on Iterable<ElementType> {
  ElementType? get firstOrNull {
    final elementIterator = iterator;
    return elementIterator.moveNext() ? elementIterator.current : null;
  }
}
