import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import 'screens/assistant_screen.dart';
import 'screens/client_detail_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/lists_screens.dart';
import 'screens/overview_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets/brand.dart';
import 'widgets/common.dart';
import 'widgets/update_banner.dart';

/// Main navigation: a side rail on a laptop, a bottom bar on a phone.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _all = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
    (Icons.folder_outlined, Icons.folder, 'Projects'),
    (Icons.task_alt_outlined, Icons.task_alt, 'Work'),
    (Icons.people_outline, Icons.people, 'Clients'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      'Finance',
    ),
  ];

  /// Finance is the owner's only.
  List<(IconData, IconData, String)> get _pages =>
      context.read<Repository>().isOwner ? _all : _all.sublist(0, 4);

  Widget _body() => switch (_index) {
    0 => const OverviewScreen(),
    1 => const ProjectsScreen(),
    2 => const WorkScreen(),
    3 => const ClientsScreen(),
    _ => const FinanceScreen(),
  };

  /// The update banner, when a new version of the Windows app is ready,
  /// above the page.
  Widget _withUpdates(Widget page) => Column(
    children: [
      const UpdateBanner(),
      Expanded(child: page),
    ],
  );

  void _openAssistant() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AssistantScreen()),
  );

  void _openSettings() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (_index >= _pages.length) _index = 0;
    final actions = [
      IconButton(
        tooltip: 'To cover',
        icon: const Icon(Icons.fact_check_outlined),
        onPressed: _openAssistant,
      ),
      const SyncBadge(),
      IconButton(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined),
        onPressed: _openSettings,
      ),
      const SizedBox(width: 4),
    ];

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              minWidth: 92,
              leading: const Padding(
                padding: EdgeInsets.only(top: 20, bottom: 28),
                child: AkMonogram(size: 44),
              ),
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final p in _pages)
                  NavigationRailDestination(
                    icon: Icon(p.$1),
                    selectedIcon: Icon(p.$2),
                    label: Text(p.$3),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
              ],
            ),
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  toolbarHeight: 64,
                  title: Row(
                    children: [
                      Text(_pages[_index].$3),
                      const SizedBox(width: 12),
                      Text(
                        repo.companyName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AkColors.of(context).onChromeMuted,
                        ),
                      ),
                    ],
                  ),
                  actions: actions,
                ),
                body: _withUpdates(_body()),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const AkMonogram(size: 30),
            const SizedBox(width: 12),
            Flexible(
              child: Text(_pages[_index].$3, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: actions,
      ),
      body: _withUpdates(_body()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final p in _pages)
            NavigationDestination(
              icon: Icon(p.$1),
              selectedIcon: Icon(p.$2),
              label: p.$3,
            ),
        ],
      ),
    );
  }
}
