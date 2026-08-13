import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/theme_preset.dart';

/// 主題商店：免費/付費主題選擇與解鎖
class ThemeSelectScreen extends StatelessWidget {
  const ThemeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();

    return Scaffold(
      appBar: AppBar(title: const Text('主題商店')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '自訂你的記帳風格',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '免費 2 款 + 付費 4 款主題。付費主題一次解鎖，終身使用。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final preset in kThemePresets)
            _ThemeCard(
              preset: preset,
              selected: budgetController.themePreset.id == preset.id,
              unlocked: budgetController.isThemeUnlocked(preset),
              onTap: () => _onTap(context, budgetController, preset),
            ),
          const SizedBox(height: 8),
          Text(
            '※ 付費為示範模式（本機解鎖）。正式版將串接 App Store / Google Play 內購。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  void _onTap(
    BuildContext context,
    BudgetController budgetController,
    ThemePreset preset,
  ) {
    if (budgetController.isThemeUnlocked(preset)) {
      budgetController.setTheme(preset.id);
      return;
    }
    // 付費未解鎖 → 購買確認
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('解鎖「${preset.name}」主題'),
        content: Text('一次付費 NT\$90，終身使用此主題。\n\n${preset.description}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              budgetController.unlockTheme(preset.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🎨 已解鎖「${preset.name}」主題！')),
              );
            },
            child: const Text('購買 NT\$90'),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemePreset preset;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;
  const _ThemeCard({
    required this.preset,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 主題預覽色塊
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      preset.seedColor,
                      Color.lerp(preset.seedColor, Colors.white, 0.4)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          preset.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        if (preset.premium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB8860B),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '免費',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preset.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: scheme.primary)
              else if (preset.premium && !unlocked)
                const Icon(Icons.lock_outline, color: Colors.grey)
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
