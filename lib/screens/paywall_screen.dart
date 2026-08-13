import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';

/// 升級 Pro 畫面：付費功能分層展示（示範模式）
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();
    final scheme = Theme.of(context).colorScheme;

    if (budgetController.isPro) {
      return Scaffold(
        appBar: AppBar(title: const Text('零基記帳 Pro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 80,
                color: Color(0xFFFFD700),
              ),
              const SizedBox(height: 16),
              Text(
                '你已是 Pro 會員 🎉',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('感謝支持！所有功能與主題已全面解鎖。'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('升級 Pro')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  size: 56,
                  color: Color(0xFFFFD700),
                ),
                const SizedBox(height: 12),
                Text(
                  '零基記帳 Pro',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  '付一次 · 用永久',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  'NT\$590',
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(color: Colors.white),
                ),
                const Text(
                  '終身買斷（示範模式）',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('免費版 vs Pro', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _CompareRow(
            icon: Icons.category_outlined,
            label: '預算類別',
            free: '限 3 個',
            pro: '無限',
          ),
          _CompareRow(
            icon: Icons.palette_outlined,
            label: '主題商店',
            free: '2 款',
            pro: '全部 6 款',
          ),
          _CompareRow(
            icon: Icons.insert_chart_outlined,
            label: '報表',
            free: '基礎圓環圖',
            pro: '全部報表',
          ),
          _CompareRow(
            icon: Icons.cloud_outlined,
            label: '雲端備份',
            free: '—',
            pro: '即將推出',
          ),
          _CompareRow(
            icon: Icons.people_outline,
            label: '共同帳本',
            free: '1 個共同帳本',
            pro: '無限（未來）',
          ),
          _CompareRow(
            icon: Icons.ad_units_outlined,
            label: '廣告',
            free: '有',
            pro: '無廣告',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              await budgetController.upgradeToPro();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🎉 已升級為 Pro 會員！')),
                );
              }
            },
            icon: const Icon(Icons.workspace_premium),
            label: const Text('立即升級 NT\$590'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '※ 示範模式：正式版將串接 App Store / Google Play 內購，付款後自動解鎖。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String free;
  final String pro;
  const _CompareRow({
    required this.icon,
    required this.label,
    required this.free,
    required this.pro,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(label),
        subtitle: Row(
          children: [
            Text('免費：$free', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(width: 12),
            Text(
              'Pro：$pro',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
