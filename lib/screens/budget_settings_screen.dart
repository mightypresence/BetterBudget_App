import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../data/repository.dart';
import '../models/budget_category.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

/// 預算設定：規劃開關 + 類別 CRUD（含顏色自訂）
class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final _nameController = TextEditingController();
  final _limitCtrl = TextEditingController();
  String _editId = '';
  bool _isEditing = false;
  int _selectedColor = 0; // 0 = 自動分配

  @override
  void dispose() {
    _nameController.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _editId = '';
      _isEditing = false;
      _nameController.clear();
      _limitCtrl.clear();
      _selectedColor = 0;
    });
  }

  void _edit(BudgetCategory budgetController) {
    setState(() {
      _editId = budgetController.id;
      _isEditing = true;
      _nameController.text = budgetController.name;
      _limitCtrl.text = budgetController.monthlyLimit > 0
          ? budgetController.monthlyLimit.toStringAsFixed(0)
          : '';
      _selectedColor = budgetController.colorValue;
    });
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final budgetController = context.read<BudgetController>();
    if (!_isEditing && !budgetController.canAddCategory) {
      // 免費版類別上限 → 引導升級
      if (context.mounted) {
        _showUpgradePrompt(context);
      }
      return;
    }
    final limit = double.tryParse(_limitCtrl.text) ?? 0;
    final categoryId = _isEditing
        ? _editId
        : 'cat-${DateTime.now().microsecondsSinceEpoch}';
    await budgetController.upsertCategory(
      BudgetCategory(
        id: categoryId,
        name: name,
        monthlyLimit: limit < 0 ? 0 : limit,
        iconName: 'category',
        colorValue: _selectedColor,
      ),
    );
    _resetForm();
  }

  void _showUpgradePrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('免費版類別已滿'),
        content: const Text('免費版最多 3 個預算類別。\n升級 Pro 即可無限新增類別、解鎖全部主題與報表。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('以後再說'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            },
            child: const Text('查看 Pro'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();

    return Scaffold(
      appBar: AppBar(title: const Text('預算設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('預算規劃'),
              subtitle: const Text('開啟後，記錄收入會詢問你如何分配到預算'),
              value: budgetController.planningEnabled,
              onChanged: (selectedValue) =>
                  budgetController.setPlanningEnabled(selectedValue),
            ),
          ),
          const SizedBox(height: 16),
          Text('類別與每月上限', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (budgetController.categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '還沒有類別。先新增一個，例如「伙食」並設定每月上限。',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          // 類別列表（長按拖拽排序）
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: budgetController.categories.length,
            onReorderItem: (oldIndex, newIndex) {
              final categories = List<BudgetCategory>.from(
                budgetController.categories,
              );
              final moved = categories.removeAt(oldIndex);
              categories.insert(newIndex, moved);
              budgetController.reorderCategories(categories);
            },
            itemBuilder: (context, itemIndex) {
              final category = budgetController.categories[itemIndex];
              final color = AppColors.categoryColorFor(category, itemIndex);
              return Card(
                key: ValueKey(category.id),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(_iconFor(category.iconName), color: color),
                  ),
                  title: Text(category.name),
                  subtitle: Text(
                    category.hasLimit
                        ? '每月上限 NT\$${category.monthlyLimit.toStringAsFixed(0)}'
                        : '未設上限',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(category),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          try {
                            await budgetController.removeCategory(category.id);
                            if (_editId == category.id) _resetForm();
                          } on CategoryInUseException catch (removalConflict) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(removalConflict.userMessage),
                              ),
                            );
                          }
                        },
                      ),
                      // 拖拽把手
                      ReorderableDragStartListener(
                        index: itemIndex,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_indicator, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          const Text(
            '長按右側 ≡ 圖示拖拽，可自訂類別順序',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? '編輯類別' : '新增類別',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '名稱（如：伙食）'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '每月上限（留空 = 不設上限）',
                      prefixText: 'NT\$ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('顏色', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 自動分配
                      _ColorDot(
                        color: Colors.transparent,
                        borderColor: Theme.of(context).colorScheme.outline,
                        selected: _selectedColor == 0,
                        onTap: () => setState(() => _selectedColor = 0),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      for (
                        var colorIndex = 0;
                        colorIndex < AppColors.categoryColors.length;
                        colorIndex++
                      )
                        _ColorDot(
                          color: AppColors.categoryColors[colorIndex],
                          borderColor: AppColors.categoryColors[colorIndex],
                          selected:
                              _selectedColor ==
                              AppColors.categoryColors[colorIndex].toARGB32(),
                          onTap: () => setState(
                            () => _selectedColor = AppColors
                                .categoryColors[colorIndex]
                                .toARGB32(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveCategory,
                          icon: const Icon(Icons.check),
                          label: Text(_isEditing ? '儲存修改' : '新增'),
                        ),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _resetForm,
                          icon: const Icon(Icons.close),
                          tooltip: '取消編輯',
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

class _ColorDot extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final bool selected;
  final VoidCallback onTap;
  final Widget? child;
  const _ColorDot({
    required this.color,
    required this.borderColor,
    required this.selected,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : borderColor,
            width: selected ? 3 : 1,
          ),
        ),
        child: child,
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
