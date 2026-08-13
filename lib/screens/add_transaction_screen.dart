import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import 'allocation_screen.dart';
import 'budget_settings_screen.dart';
import 'transactions_screen.dart';

/// 快速記帳首屏：開啟 App 第一眼，快速記下收入或支出
class AddTransactionScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const AddTransactionScreen({super.key, this.onOpenDrawer});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  TransactionType _type = TransactionType.expense;
  final _amountController = TextEditingController();
  String get _amount => _amountController.text;
  String? _categoryId;
  DateTime _date = DateTime.now();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() async {
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0) {
      _toast('請輸入金額');
      return;
    }
    final budgetController = context.read<BudgetController>();
    final transaction = await budgetController.addTransaction(
      type: _type,
      amount: amount,
      categoryId: _type == TransactionType.expense ? _categoryId : null,
      date: _date,
      note: _noteController.text.trim(),
    );

    if (!mounted) return;

    if (_type == TransactionType.income &&
        transaction != null &&
        budgetController.planningEnabled) {
      // 收入 + 預算規劃開啟 → 引導分配
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AllocationScreen(
            mode: AllocationMode.income,
            incomeTransactionId: transaction.id,
          ),
        ),
      );
      _resetForm();
    } else if (_type == TransactionType.expense &&
        _categoryId != null &&
        _isOverBudget(budgetController, _categoryId!)) {
      _toast('這個類別本月已超支，要注意喔');
      _resetForm();
    } else {
      _toast('已記錄 ✓');
      _resetForm();
    }
  }

  bool _isOverBudget(BudgetController budgetController, String categoryId) {
    final stats = budgetController.service.categoryStats(
      budgetController.month,
    );
    final runningTotal = stats
        .where((currentItem) => currentItem.category.id == categoryId)
        .firstOrNull;
    return runningTotal != null &&
        runningTotal.category.hasLimit &&
        runningTotal.spent > runningTotal.category.monthlyLimit;
  }

  void _resetForm() {
    setState(() {
      _amountController.clear();
      _categoryId = null;
      _noteController.clear();
      _date = DateTime.now();
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();
    final categories = budgetController.categories;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // 從主頁 FAB 進入 = 全屏頁面 → 顯示返回；從側邊欄/首屏進入 → 顯示 ☰
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu),
                tooltip: '選單',
                onPressed: widget.onOpenDrawer,
              ),
        title: const Text('記一筆'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: '全部交易',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 支出 / 收入 大卡片切換
            Row(
              children: [
                _TypeCard(
                  label: '支出',
                  icon: Icons.arrow_downward,
                  selected: _type == TransactionType.expense,
                  color: scheme.error,
                  onTap: () => setState(() => _type = TransactionType.expense),
                ),
                const SizedBox(width: 12),
                _TypeCard(
                  label: '收入',
                  icon: Icons.arrow_upward,
                  selected: _type == TransactionType.income,
                  color: scheme.primary,
                  onTap: () => setState(() => _type = TransactionType.income),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 大金額輸入區
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Text('金額', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    controller: _amountController,
                    onChanged: (selectedValue) {
                      final cleaned = selectedValue.replaceAll(
                        RegExp(r'[^0-9.]'),
                        '',
                      );
                      if (cleaned != selectedValue) {
                        _amountController.text = cleaned;
                        _amountController.selection = TextSelection.collapsed(
                          offset: cleaned.length,
                        );
                      }
                      setState(() {});
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    // 限制最多 12 位整數（+小數點），避免 double 大數變科學計數
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(13),
                    ],
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: _type == TransactionType.income
                          ? scheme.primary
                          : scheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: Theme.of(context).textTheme.displayLarge
                          ?.copyWith(
                            color: scheme.outlineVariant,
                            fontWeight: FontWeight.w600,
                          ),
                      prefixText: 'NT\$ ',
                      prefixStyle: Theme.of(context).textTheme.displayLarge
                          ?.copyWith(
                            color: scheme.outline,
                            fontWeight: FontWeight.w600,
                          ),
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 類別選擇（支出時）
            if (_type == TransactionType.expense) ...[
              Text('類別', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('還沒有類別'),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BudgetSettingsScreen(),
                            ),
                          ),
                          child: const Text('去設定類別'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 104,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.6,
                        ),
                    itemCount: categories.length,
                    itemBuilder: (context, itemIndex) {
                      final category = categories[itemIndex];
                      final color = AppColors.categoryColorFor(
                        category,
                        itemIndex,
                      );
                      final selected = _categoryId == category.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _categoryId = category.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.25)
                                : scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _iconFor(category.iconName),
                                color: selected ? color : scheme.onSurface,
                                size: 22,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                category.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // 日期 + 備註
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text('${_date.year}/${_date.month}/${_date.day}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (selectedDate != null) {
                        setState(() => _date = selectedDate);
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: '備註（選填）',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: Icon(
                _type == TransactionType.income
                    ? Icons.arrow_upward
                    : Icons.check,
                size: 20,
              ),
              label: Text(_type == TransactionType.income ? '記錄收入' : '記錄支出'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 72,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? color : scheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? color : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// icon 名稱 → Material Icon（維持與既有資料相容）
IconData _iconFor(String name) {
  const icons = <String, IconData>{
    'restaurant': Icons.restaurant,
    'shopping_cart': Icons.shopping_cart,
    'directions_car': Icons.directions_car,
    'home': Icons.home,
    'sports_esports': Icons.sports_esports,
    'school': Icons.school,
    'medical_services': Icons.medical_services,
    'savings': Icons.savings,
    'flight': Icons.flight,
    'pets': Icons.pets,
    'category': Icons.category,
  };
  return icons[name] ?? Icons.category;
}

extension<ElementType> on Iterable<ElementType> {
  ElementType? get firstOrNull {
    final elementIterator = iterator;
    return elementIterator.moveNext() ? elementIterator.current : null;
  }
}
