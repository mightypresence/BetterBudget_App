import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import 'add_transaction_screen.dart';
import 'budget_settings_screen.dart';
import 'home_screen.dart';
import 'members_screen.dart';
import 'shared_ledger_screen.dart';
import 'theme_select_screen.dart';
import 'transactions_screen.dart';
import 'paywall_screen.dart';

/// 根畫面：側邊抽屜導航
/// 主頁（儀表板）為首屏；快速記帳從主頁 FAB / 側邊欄進入
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0; // 0=主頁 1=共同帳本 2=快速記帳

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();
  void _closeDrawer() => _scaffoldKey.currentState?.closeDrawer();

  void _goTo(int itemIndex) {
    _closeDrawer();
    setState(() => _index = itemIndex);
  }

  @override
  Widget build(BuildContext context) {
    final budgetController = context.watch<BudgetController>();
    return Scaffold(
      key: _scaffoldKey,
      drawer: NavigationDrawer(
        selectedIndex: _index <= 2 ? _index : null,
        onDestinationSelected: _goTo,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '零基記帳',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '讓每一塊錢都有任務',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          const NavigationDrawerDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: Text('主頁'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: Text('共同帳本'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: Text('快速記帳'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 16, 4),
            child: Text(
              '管理',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('預算設定'),
            onTap: () {
              _closeDrawer();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: const Text('成員管理'),
            onTap: () {
              _closeDrawer();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MembersScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('全部交易'),
            onTap: () {
              _closeDrawer();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransactionsScreen()),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 16, 4),
            child: Text(
              '其他',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: Icon(
              budgetController.isPro
                  ? Icons.workspace_premium
                  : Icons.workspace_premium_outlined,
              color: budgetController.isPro ? const Color(0xFFFFD700) : null,
            ),
            title: Text(budgetController.isPro ? '零基記帳 Pro' : '升級 Pro'),
            subtitle: Text(
              budgetController.isPro ? '已解鎖全部功能' : '終身 NT\$590，付一次用永久',
            ),
            onTap: () {
              _closeDrawer();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主題商店'),
            subtitle: const Text('付費主題解鎖'),
            onTap: () {
              _closeDrawer();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSelectScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('深色模式'),
            trailing: DropdownButton<ThemeMode>(
              value: budgetController.themeMode,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('跟隨系統')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('淺色')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
              ],
              onChanged: (selectedValue) => selectedValue == null
                  ? null
                  : budgetController.setThemeMode(selectedValue),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '版本 1.0.0',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenDrawer: _openDrawer),
          SharedLedgerScreen(onOpenDrawer: _openDrawer),
          if (_index == 2)
            AddTransactionScreen(onOpenDrawer: _openDrawer)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
