import 'package:flutter/material.dart';

import '../main.dart';
import '../tabs/admin_settings_tab.dart';
import '../tabs/trainer_customers_tab.dart';
import '../tabs/trainer_groups_tab.dart';
import '../tabs/trainer_portal_pages.dart';

class TrainerHomeScreen extends StatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  int _selectedIndex = 0;

  void _openRoute(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      appFrontColor.value,
                      appFrontColor.value.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Trainer-Menü',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Einstellungen'),
                onTap: () => _openRoute(context, const AdminSettingsTab()),
              ),
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('Trainerstamm'),
                onTap: () => _openRoute(context, const TrainerRosterPage()),
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Kundenstamm'),
                onTap: () => _openRoute(context, const TrainerCustomersTab()),
              ),
              ListTile(
                leading: const Icon(Icons.groups),
                title: const Text('Gruppenstamm'),
                onTap: () => _openRoute(context, const TrainerGroupsTab()),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('Trainer'),
        automaticallyImplyLeading: false,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          TrainerDashboardTab(),
          TrainerBillingTab(),
          TrainerManageTab(),
          SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 3) {
            showModalBottomSheet<void>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Einstellungen'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openRoute(context, const AdminSettingsTab());
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.badge),
                      title: const Text('Trainerstamm'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openRoute(context, const TrainerRosterPage());
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('Kundenstamm'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openRoute(context, const TrainerCustomersTab());
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.groups),
                      title: const Text('Gruppenstamm'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openRoute(context, const TrainerGroupsTab());
                      },
                    ),
                  ],
                ),
              ),
            );
            return;
          }
          setState(() => _selectedIndex = index);
        },
        selectedItemColor: appFrontColor.value,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Rechnung'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Verwalten'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menü'),
        ],
      ),
    );
  }
}
