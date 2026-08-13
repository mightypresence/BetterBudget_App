import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';
import 'allocation_screen.dart';
import 'budget_settings_screen.dart';
import 'transactions_screen.dart';

/// 主頁儀表板：Hero 總覽 + 待分配 + 圓環圖 + 類別卡片 + 最近交易
class HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const HomeScreen({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();
    final currencyFormat = NumberFormat.currency(
      locale: 'zh_TW',
      symbol: 'NT\$',
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: '選單',
          onPressed: onOpenDrawer,
        ),
        title: Text(
          '${budgetController.month.year}年${budgetController.month.month}月 · 主頁',
        ),
        actions: [
          // 🎯 規劃預算（藏在角落的入口）
          IconButton(
            icon: const Icon(Icons.track_changes_outlined),
            tooltip: '規劃預算',
            onPressed: () => _openPlanning(context, budgetController),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(
            budgetController: budgetController,
            currencyFormat: currencyFormat,
          ),
          const SizedBox(height: 12),
          if (budgetController.unassigned > 0) ...[
            _UnassignedBanner(
              budgetController: budgetController,
              currencyFormat: currencyFormat,
            ),
            const SizedBox(height: 12),
          ],
          if (budgetController.categories.isNotEmpty) ...[
            _DonutChart(
              budgetController: budgetController,
              currencyFormat: currencyFormat,
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('類別預算', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BudgetSettingsScreen(),
                  ),
                ),
                child: const Text('管理'),
              ),
            ],
          ),
          if (budgetController.categories.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('還沒有預算類別'),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BudgetSettingsScreen(),
                        ),
                      ),
                      child: const Text('設定預算'),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: budgetController.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, itemIndex) => _CategoryCard(
                  budgetController: budgetController,
                  index: itemIndex,
                  currencyFormat: currencyFormat,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('最近交易', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                ),
                child: const Text('查看全部'),
              ),
            ],
          ),
          ..._recentTransactions(budgetController).map(
            (transaction) => _RecentTransactionRow(
              budgetController: budgetController,
              transaction: transaction,
            ),
          ),
          if (budgetController.transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '還沒有交易，按「記一筆」開始吧。',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('記一筆'),
      ),
    );
  }

  List<Transaction> _recentTransactions(BudgetController budgetController) {
    final list = budgetController.transactions.toList()
      ..sort(
        (allocation, rightValue) => rightValue.date.compareTo(allocation.date),
      );
    return list.take(5).toList();
  }

  void _openPlanning(BuildContext context, BudgetController budgetController) {
    // 角落入口：有未分配收入 → 引導分配；否則 → 預算設定
    if (budgetController.unassigned > 0) {
      final transaction = budgetController.service
          .pendingIncomesOfMonth(budgetController.month)
          .firstOrNull;
      if (transaction != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllocationScreen(
              mode: AllocationMode.income,
              incomeTransactionId: transaction.id,
            ),
          ),
        );
        return;
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BudgetSettingsScreen()),
    );
  }
}

// ── Hero 總覽卡 ────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final BudgetController budgetController;
  final NumberFormat currencyFormat;
  const _HeroCard({
    required this.budgetController,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalBudget = budgetController.categories.fold<double>(
      0,
      (runningTotal, category) => runningTotal + category.monthlyLimit,
    );
    final ratio = totalBudget > 0
        ? (budgetController.expense / totalBudget).clamp(0.0, 1.2)
        : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [scheme.primaryContainer, scheme.surfaceContainer]
              : [AppColors.primaryContainer, const Color(0xFFEFF5F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本月可用餘額', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            'NT\$ ${formatMoney(budgetController.balance)}',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.toDouble(),
              minHeight: 8,
              backgroundColor: scheme.onPrimaryContainer.withValues(
                alpha: 0.15,
              ),
              valueColor: AlwaysStoppedAnimation(
                ratio > 1
                    ? scheme.error
                    : ratio > 0.8
                    ? const Color(0xFFE8B55B)
                    : scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '收入',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '+NT\$ ${formatMoney(budgetController.income)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '支出',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '-NT\$ ${formatMoney(budgetController.expense)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 待分配提醒 ──────────────────────────────────────────

class _UnassignedBanner extends StatelessWidget {
  final BudgetController budgetController;
  final NumberFormat currencyFormat;
  const _UnassignedBanner({
    required this.budgetController,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final transaction = budgetController.service
            .pendingIncomesOfMonth(budgetController.month)
            .firstOrNull;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllocationScreen(
              // 有未分配收入 → 直接進該筆的分配；否則開待分配池
              mode: transaction != null
                  ? AllocationMode.income
                  : AllocationMode.unassignedPool,
              incomeTransactionId: transaction?.id,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF4A3F28), const Color(0xFF3A3220)]
                : [AppColors.warmYellow, AppColors.warmYellowDeep],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.savings, color: Color(0xFFB8860B), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '還有 NT\$ ${formatMoney(budgetController.unassigned)} 待規劃',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark
                          ? const Color(0xFFFFE8B0)
                          : const Color(0xFF6B4E00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '讓每一塊錢都有任務',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? const Color(0xFFD9C9A0)
                          : const Color(0xFF8A6D2B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? const Color(0xFFFFE8B0) : const Color(0xFF6B4E00),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 預算圓環圖 ──────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  final BudgetController budgetController;
  final NumberFormat currencyFormat;
  const _DonutChart({
    required this.budgetController,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = budgetController.service.categoryStats(
      budgetController.month,
    );
    final totalAvailable = stats.fold<double>(
      0,
      (sum, stat) => sum + stat.limit + stat.allocated,
    );
    final usagePercent = budgetUsagePercent(
      budgetController.expense,
      totalAvailable,
    );

    final sections = <PieChartSectionData>[];
    for (var itemIndex = 0; itemIndex < stats.length; itemIndex++) {
      if (stats[itemIndex].spent <= 0) continue;
      sections.add(
        PieChartSectionData(
          value: stats[itemIndex].spent,
          color: AppColors.categoryColorFor(
            stats[itemIndex].category,
            itemIndex,
          ),
          radius: 16,
          showTitle: false,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本月預算', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (sections.isEmpty)
                    Icon(
                      Icons.pie_chart_outline,
                      size: 80,
                      color: scheme.outlineVariant,
                    )
                  else
                    PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 48,
                        sectionsSpace: 2,
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '已用 $usagePercent%',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '總支出 NT\$ ${formatMoney(budgetController.expense)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (var itemIndex = 0; itemIndex < stats.length; itemIndex++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.categoryColorFor(
                            stats[itemIndex].category,
                            itemIndex,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stats[itemIndex].category.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 類別卡片（水平） ────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final BudgetController budgetController;
  final int index;
  final NumberFormat currencyFormat;
  const _CategoryCard({
    required this.budgetController,
    required this.index,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final runningTotal = budgetController.service.categoryStats(
      budgetController.month,
    )[index];
    final color = AppColors.categoryColorFor(runningTotal.category, index);
    final over =
        runningTotal.category.hasLimit &&
        runningTotal.spent > runningTotal.category.monthlyLimit;
    final ratio = runningTotal.category.monthlyLimit > 0
        ? (runningTotal.spent / runningTotal.category.monthlyLimit)
              .clamp(0.0, 1.2)
              .toDouble()
        : 0.0;

    return SizedBox(
      width: 130,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconFor(runningTotal.category.iconName),
                      color: color,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  if (over)
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: scheme.error,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                runningTotal.category.name,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: scheme.outlineVariant.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation(
                    over ? scheme.error : color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'NT\$ ${formatMoney(runningTotal.spent)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                over
                    ? '超 ${formatMoney(runningTotal.spent - runningTotal.category.monthlyLimit)}'
                    : '剩 ${formatMoney(runningTotal.remaining)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: over ? scheme.error : color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int budgetUsagePercent(double spent, double totalAvailable) =>
    totalAvailable > 0 ? (spent / totalAvailable * 100).round() : 0;

// ── 最近交易列 ──────────────────────────────────────────

class _RecentTransactionRow extends StatelessWidget {
  final BudgetController budgetController;
  final Transaction transaction;
  const _RecentTransactionRow({
    required this.budgetController,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = transaction.type == TransactionType.income;
    final catIndex = budgetController.categories.indexWhere(
      (category) => category.id == transaction.categoryId,
    );
    final color = transaction.categoryId != null && catIndex >= 0
        ? AppColors.categoryColorFor(
            budgetController.categories[catIndex],
            catIndex,
          )
        : scheme.primary;
    final catName = transaction.categoryId != null && catIndex >= 0
        ? budgetController.categories[catIndex].name
        : (isIncome ? '收入' : '支出');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 16,
          ),
        ),
        title: Text(
          transaction.note.isEmpty ? catName : transaction.note,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: Text(
          '${transaction.date.month}/${transaction.date.day} · $catName',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${formatMoney(transaction.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isIncome ? scheme.primary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

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
