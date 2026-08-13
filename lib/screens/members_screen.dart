import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/member.dart';

/// 成員管理：新增/編輯成員、設定收入與私房錢
class MembersScreen extends StatefulWidget {
  final String? initialMemberId;
  const MembersScreen({super.key, this.initialMemberId});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _nameController = TextEditingController();
  final _actualIncomeController = TextEditingController();
  final _shownIncomeController = TextEditingController();
  String _editId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialMemberId = widget.initialMemberId;
      if (initialMemberId != null) {
        final budgetController = context.read<BudgetController>();
        final member = budgetController.members
            .where((currentItem) => currentItem.id == initialMemberId)
            .firstOrNull;
        if (member != null) _edit(member);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _actualIncomeController.dispose();
    _shownIncomeController.dispose();
    super.dispose();
  }

  void _edit(Member member) {
    setState(() {
      _editId = member.id;
      _nameController.text = member.name;
      _actualIncomeController.text = member.actualIncome > 0
          ? member.actualIncome.toStringAsFixed(0)
          : '';
      _shownIncomeController.text = member.shownIncome > 0
          ? member.shownIncome.toStringAsFixed(0)
          : '';
    });
  }

  void _reset() {
    setState(() {
      _editId = '';
      _nameController.clear();
      _actualIncomeController.clear();
      _shownIncomeController.clear();
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final actual = double.tryParse(_actualIncomeController.text) ?? 0;
    final shown = double.tryParse(_shownIncomeController.text) ?? actual;
    final budgetController = context.read<BudgetController>();
    final memberId = _editId.isNotEmpty
        ? _editId
        : 'mem-${DateTime.now().microsecondsSinceEpoch}';
    await budgetController.upsertMember(
      Member(
        id: memberId,
        name: name,
        actualIncome: actual < 0 ? 0 : actual,
        shownIncome: shown < 0
            ? 0
            : (shown > actual && actual > 0 ? actual : shown),
      ),
    );
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();
    return Scaffold(
      appBar: AppBar(title: const Text('成員管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '成員（可邀請伴侶、家人加入共同帳本）',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (budgetController.members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '還沒有成員。新增第一個成員開始建立共同帳本。',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          for (final member in budgetController.members)
            Card(
              child: ListTile(
                title: Text(member.name),
                subtitle: Text(
                  '實際收入 ${member.actualIncome.toStringAsFixed(0)}'
                  ' · 顯示 ${member.shownIncome.toStringAsFixed(0)}'
                  '${member.privateSavings > 0 ? ' · 🫙 私房錢 ${member.privateSavings.toStringAsFixed(0)}' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(member),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await budgetController.removeMember(member.id);
                        if (_editId == member.id) _reset();
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _editId.isEmpty ? '新增成員' : '編輯成員',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '名稱（如：小美）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _actualIncomeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '實際月收入（只有自己看得到）',
                      prefixText: 'NT\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🫙 私房錢功能：在共同帳本顯示的收入可以低於實際收入，差額只有自己知道。',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _shownIncomeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '共同帳本顯示收入（可留空 = 同實際）',
                      prefixText: 'NT\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.check),
                          label: Text(_editId.isEmpty ? '新增成員' : '儲存'),
                        ),
                      ),
                      if (_editId.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _reset,
                          icon: const Icon(Icons.close),
                          tooltip: '取消',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
