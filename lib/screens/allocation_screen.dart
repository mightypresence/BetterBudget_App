import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/allocation.dart';
import '../models/transaction.dart';

enum AllocationMode { income, unassignedPool }

/// 收入引導分配（核心特色畫面）
class AllocationScreen extends StatefulWidget {
  final AllocationMode mode;
  final String? incomeTransactionId;

  const AllocationScreen({
    super.key,
    required this.mode,
    this.incomeTransactionId,
  });

  @override
  State<AllocationScreen> createState() => _AllocationScreenState();
}

class _AllocationScreenState extends State<AllocationScreen> {
  final Map<String, TextEditingController> _amountControllers = {};
  String? _currentTxId;
  Transaction? _income;
  bool _incomeUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final budgetController = context.read<BudgetController>();
    if (widget.mode == AllocationMode.income &&
        widget.incomeTransactionId != null) {
      _openIncome(widget.incomeTransactionId!);
    } else {
      // 待分配池：列出本月未分配收入
      final unallocated = budgetController.service.pendingIncomesOfMonth(
        budgetController.month,
      );
      if (unallocated.isEmpty) {
        setState(() => _currentTxId = null);
      } else if (unallocated.length == 1) {
        _openIncome(unallocated.first.id);
      } else {
        // 多筆：彈出選擇
        final picked = await showModalBottomSheet<Transaction>(
          context: context,
          builder: (ctx) => SafeArea(
            child: ListView(
              children: unallocated
                  .map(
                    (transaction) => ListTile(
                      title: Text(
                        transaction.note.isEmpty ? '收入' : transaction.note,
                      ),
                      subtitle: Text(
                        NumberFormat.currency(
                          locale: 'zh_TW',
                          symbol: 'NT\$',
                        ).format(transaction.amount),
                      ),
                      onTap: () => Navigator.pop(ctx, transaction),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        if (picked != null && mounted) {
          _openIncome(picked.id);
        } else if (mounted) {
          setState(() => _currentTxId = null);
        }
      }
    }
  }

  void _openIncome(String txId) {
    final budgetController = context.read<BudgetController>();
    final transaction = budgetController.service.findIncomeById(txId);
    if (transaction == null) {
      if (mounted) {
        setState(() {
          _currentTxId = null;
          _income = null;
          _incomeUnavailable = true;
        });
      }
      return;
    }
    // 載入既有分配
    final existing = budgetController.service.repository
        .getIncomeAllocations()
        .where((allocation) => allocation.transactionId == txId)
        .firstOrNull;
    setState(() {
      _currentTxId = txId;
      _income = transaction;
      _incomeUnavailable = false;
      for (final controller in _amountControllers.values) {
        controller.dispose();
      }
      _amountControllers.clear();
      for (final category in budgetController.categories) {
        final prev = existing?.allocations
            .where((allocation) => allocation.categoryId == category.id)
            .firstOrNull;
        _amountControllers[category.id] = TextEditingController(
          text: prev != null && prev.amount > 0
              ? prev.amount.toStringAsFixed(0)
              : '',
        );
      }
    });
  }

  @override
  void dispose() {
    for (final budgetController in _amountControllers.values) {
      budgetController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();
    final currencyFormat = NumberFormat.currency(
      locale: 'zh_TW',
      symbol: 'NT\$',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('規劃收入')),
      body: _currentTxId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _incomeUnavailable
                        ? Icons.search_off_outlined
                        : Icons.check_circle_outline,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _incomeUnavailable ? '找不到這筆收入' : '本月收入都已規劃完成 🎉',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_incomeUnavailable) ...[
                    const SizedBox(height: 8),
                    const Text('收入可能已被刪除，請返回後重新選擇。'),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('返回'),
                    ),
                  ],
                ],
              ),
            )
          : _buildAllocationBody(budgetController, currencyFormat),
    );
  }

  Widget _buildAllocationBody(
    BudgetController budgetController,
    NumberFormat currencyFormat,
  ) {
    final incomeAmount = _income!.amount;
    double allocated = 0;
    for (final entry in _amountControllers.entries) {
      allocated += double.tryParse(entry.value.text) ?? 0;
    }
    final remaining = incomeAmount - allocated;
    final valid = allocated > 0 && remaining >= -1e-6;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('這筆收入', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(incomeAmount),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_income!.note.isNotEmpty)
                  Text(
                    _income!.note,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('分配到哪些預算？', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '每個類別輸入金額，總和不可超過 ${currencyFormat.format(incomeAmount)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final category in budgetController.categories)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(
                  category.colorValue,
                ).withValues(alpha: 0.2),
                child: Icon(Icons.category, color: Color(category.colorValue)),
              ),
              title: Text(category.name),
              trailing: SizedBox(
                width: 140,
                child: TextField(
                  controller: _amountControllers[category.id],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  // 限制 12 位整數（+小數點），避免 double 大數變科學計數
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(13),
                  ],
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: 'NT\$',
                    border: UnderlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已分配 ${currencyFormat.format(allocated)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  remaining >= 0
                      ? '剩餘 ${currencyFormat.format(remaining)}'
                      : '超出 ${currencyFormat.format(-remaining)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: valid ? Colors.green.shade700 : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: valid ? () => _save(budgetController, incomeAmount) : null,
          icon: const Icon(Icons.check),
          label: const Text('完成規劃'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('以後再規劃'),
        ),
      ],
    );
  }

  Future<void> _save(
    BudgetController budgetController,
    double incomeAmount,
  ) async {
    final allocations = <Allocation>[];
    for (final entry in _amountControllers.entries) {
      final selectedValue = double.tryParse(entry.value.text) ?? 0;
      if (selectedValue > 0) {
        allocations.add(
          Allocation(categoryId: entry.key, amount: selectedValue),
        );
      }
    }
    final total = allocations.fold<double>(
      0,
      (runningTotal, allocation) => runningTotal + allocation.amount,
    );
    if (total <= 0 || total > incomeAmount + 1e-6) return;
    await budgetController.saveAllocation(_currentTxId!, allocations);
    if (!mounted) return;
    Navigator.pop(context);
  }
}

extension<ElementType> on Iterable<ElementType> {
  ElementType? get firstOrNull {
    final elementIterator = iterator;
    return elementIterator.moveNext() ? elementIterator.current : null;
  }
}
