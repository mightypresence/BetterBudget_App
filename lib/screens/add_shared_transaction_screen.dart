import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/shared_transaction.dart';

/// 新增共同交易（支出/收入），選擇分攤模式
class AddSharedTransactionScreen extends StatefulWidget {
  const AddSharedTransactionScreen({super.key});

  @override
  State<AddSharedTransactionScreen> createState() =>
      _AddSharedTransactionScreenState();
}

class _AddSharedTransactionScreenState
    extends State<AddSharedTransactionScreen> {
  final _amountController = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _noteController = TextEditingController();
  final Map<String, TextEditingController> _customAmountControllers = {};
  SplitMode _mode = SplitMode.equal;
  String? _payerId;
  DateTime _date = DateTime.now();
  bool _isIncome = false;
  bool _syncToPersonal = true;

  @override
  void dispose() {
    _amountController.dispose();
    _categoryCtrl.dispose();
    _noteController.dispose();
    for (final budgetController in _customAmountControllers.values) {
      budgetController.dispose();
    }
    super.dispose();
  }

  void _initCustom(List members) {
    if (_customAmountControllers.isEmpty) {
      for (final member in members) {
        _customAmountControllers[member.id] = TextEditingController();
      }
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _toast('請輸入有效金額');
      return;
    }
    final budgetController = context.read<BudgetController>();
    final members = budgetController.members;

    // custom 模式驗證：總和 = 金額
    double customTotal = 0;
    if (_mode == SplitMode.custom) {
      for (final member in members) {
        customTotal +=
            double.tryParse(_customAmountControllers[member.id]?.text ?? '') ??
            0;
      }
      if ((customTotal - amount).abs() > 1e-6) {
        _toast('自由分攤總和需等於 $amount（目前 $customTotal）');
        return;
      }
    }
    if (_mode == SplitMode.byPayer && _payerId == null) {
      _toast('請選擇付款人');
      return;
    }

    final customAmounts = <String, double>{};
    if (_mode == SplitMode.custom) {
      for (final member in members) {
        final selectedValue =
            double.tryParse(_customAmountControllers[member.id]?.text ?? '') ??
            0;
        if (selectedValue > 0) customAmounts[member.id] = selectedValue;
      }
    }

    await budgetController.addSharedTransaction(
      SharedTransaction(
        id: 'stx-${DateTime.now().microsecondsSinceEpoch}',
        amount: amount,
        isIncome: _isIncome,
        categoryName: _categoryCtrl.text.trim(),
        date: _date,
        note: _noteController.text.trim(),
        splitMode: _mode,
        customAmounts: customAmounts,
        payerId: _mode == SplitMode.byPayer ? _payerId : null,
        syncToPersonal: _syncToPersonal && !_isIncome,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();
    final members = budgetController.members;
    _initCustom(members);

    return Scaffold(
      appBar: AppBar(title: const Text('共同交易')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('支出'),
                icon: Icon(Icons.remove_circle_outline),
              ),
              ButtonSegment(
                value: true,
                label: Text('收入'),
                icon: Icon(Icons.add_circle_outline),
              ),
            ],
            selected: {_isIncome},
            onSelectionChanged: (runningTotal) =>
                setState(() => _isIncome = runningTotal.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '金額',
              prefixText: 'NT\$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(
              labelText: '項目（如：房租、水電）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SplitMode>(
            initialValue: _mode,
            decoration: const InputDecoration(
              labelText: '分攤方式',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: SplitMode.equal, child: Text('平均分攤')),
              DropdownMenuItem(
                value: SplitMode.byIncomeRatio,
                child: Text('按收入比例分攤'),
              ),
              DropdownMenuItem(value: SplitMode.byPayer, child: Text('指定誰出錢')),
              DropdownMenuItem(value: SplitMode.custom, child: Text('自由設定')),
            ],
            onChanged: (selectedValue) =>
                setState(() => _mode = selectedValue ?? SplitMode.equal),
          ),
          const SizedBox(height: 12),
          if (_mode == SplitMode.byPayer)
            DropdownButtonFormField<String>(
              initialValue: _payerId,
              decoration: const InputDecoration(
                labelText: '誰來付？',
                border: OutlineInputBorder(),
              ),
              items: members
                  .map(
                    (member) => DropdownMenuItem(
                      value: member.id,
                      child: Text(member.name),
                    ),
                  )
                  .toList(),
              onChanged: (selectedValue) =>
                  setState(() => _payerId = selectedValue),
            ),
          if (!_isIncome)
            Card(
              child: SwitchListTile(
                title: const Text('同步到個人帳本'),
                subtitle: const Text('依分攤金額記錄到各成員的個人帳本，並扣對應預算'),
                value: _syncToPersonal,
                onChanged: (selectedValue) =>
                    setState(() => _syncToPersonal = selectedValue),
              ),
            ),
          if (_mode == SplitMode.custom) ...[
            const Text(
              '各成員分攤金額（總和須等於金額）',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            for (final member in members)
              Card(
                child: ListTile(
                  title: Text(member.name),
                  trailing: SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _customAmountControllers[member.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.right,
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
          ],
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
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
              if (selectedDate != null) setState(() => _date = selectedDate);
            },
          ),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '備註（選填）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('儲存'),
          ),
        ],
      ),
    );
  }
}
