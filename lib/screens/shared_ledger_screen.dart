import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/member.dart';
import '../models/shared_transaction.dart';
import 'add_shared_transaction_screen.dart';
import 'members_screen.dart';

/// 共同帳本首頁：總覽 + 成員結餘 + 共同交易
class SharedLedgerScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const SharedLedgerScreen({super.key, this.onOpenDrawer});

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
        title: const Text('共同帳本'),
      ),
      floatingActionButton: budgetController.members.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddSharedTransactionScreen(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('共同支出'),
            ),
      body: budgetController.members.isEmpty
          ? _EmptyState(
              onAddMember: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MembersScreen()),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _LedgerSummaryCard(
                  budgetController: budgetController,
                  currencyFormat: currencyFormat,
                ),
                const SizedBox(height: 12),
                Text('成員結餘', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final member in budgetController.members)
                  _MemberCard(
                    member: member,
                    budgetController: budgetController,
                    currencyFormat: currencyFormat,
                  ),
                const SizedBox(height: 16),
                Text('共同交易', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (budgetController.sharedTransactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '還沒有共同交易，按右下角新增一筆吧。',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                for (final transaction in budgetController.sharedTransactions)
                  _SharedTransactionTile(
                    transaction: transaction,
                    budgetController: budgetController,
                    currencyFormat: currencyFormat,
                  ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddMember;
  const _EmptyState({required this.onAddMember});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('建立你們的共同帳本'),
          const SizedBox(height: 4),
          const Text(
            '加入成員（如：你、你的伴侶），設定各自收入',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAddMember,
            icon: const Icon(Icons.person_add),
            label: const Text('新增成員'),
          ),
        ],
      ),
    );
  }
}

class _LedgerSummaryCard extends StatelessWidget {
  final BudgetController budgetController;
  final NumberFormat currencyFormat;
  const _LedgerSummaryCard({
    required this.budgetController,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${budgetController.month.year}年${budgetController.month.month}月 共同帳本',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LedgerSummaryMetric(
                  label: '總收入',
                  value: currencyFormat.format(budgetController.sharedIncome),
                ),
                _LedgerSummaryMetric(
                  label: '共同支出',
                  value: currencyFormat.format(budgetController.sharedExpense),
                ),
                _LedgerSummaryMetric(
                  label: '結餘',
                  value: currencyFormat.format(budgetController.sharedBalance),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  const _LedgerSummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;
  final BudgetController budgetController;
  final NumberFormat currencyFormat;
  const _MemberCard({
    required this.member,
    required this.budgetController,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final share = budgetController.memberShareTotal(member.id);
    final balance = budgetController.memberBalance(member.id);
    final colors = [
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.purple,
    ];
    final color = colors[member.id.hashCode.abs() % colors.length];
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(
            member.name.characters.first,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(member.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '顯示收入 ${currencyFormat.format(member.shownIncome)}'
              '${member.privateSavings > 0 ? ' · 私房錢 ${currencyFormat.format(member.privateSavings)}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '已分攤 ${currencyFormat.format(share)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '結餘',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            Text(
              currencyFormat.format(balance),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? Colors.green.shade700 : Colors.red,
              ),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MembersScreen(initialMemberId: member.id),
          ),
        ),
      ),
    );
  }
}

class _SharedTransactionTile extends StatelessWidget {
  final SharedTransaction transaction;
  final BudgetController budgetController;
  final NumberFormat currencyFormat;
  const _SharedTransactionTile({
    required this.transaction,
    required this.budgetController,
    required this.currencyFormat,
  });

  String _splitLabel() => switch (transaction.splitMode) {
    SplitMode.equal => '平均分攤',
    SplitMode.byIncomeRatio => '按收入比例',
    SplitMode.byPayer => '指定人付',
    SplitMode.custom => '自由設定',
  };

  @override
  Widget build(BuildContext context) {
    final split = budgetController.splitOf(transaction);
    final members = budgetController.members;
    final detail = split.entries
        .map((currentItem) {
          final name =
              members
                  .where((member) => member.id == currentItem.key)
                  .firstOrNull
                  ?.name ??
              '?';
          return '$name ${currencyFormat.format(currentItem.value)}';
        })
        .join('、');

    return Card(
      child: ListTile(
        leading: Icon(
          transaction.isIncome ? Icons.south_west : Icons.north_east,
          color: transaction.isIncome ? Colors.green : Colors.red,
        ),
        title: Text(
          transaction.categoryName.isEmpty
              ? (transaction.isIncome ? '共同收入' : '共同支出')
              : transaction.categoryName,
        ),
        subtitle: Text(
          '${_splitLabel()}\n$detail\n${transaction.date.month}/${transaction.date.day}${transaction.note.isEmpty ? '' : ' · ${transaction.note}'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          currencyFormat.format(transaction.amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: transaction.isIncome
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
        ),
      ),
    );
  }
}

extension<ElementType> on Iterable<ElementType> {
  ElementType? get firstOrNull {
    final elementIterator = iterator;
    return elementIterator.moveNext() ? elementIterator.current : null;
  }
}
