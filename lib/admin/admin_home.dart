import 'package:flutter/material.dart';

import '../main.dart';
import '../tabs/admin_dashboard_tab.dart';
import '../tabs/admin_settings_tab.dart';
import '../tabs/profile_tab.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin"),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const AdminDashboardTab(),
          const AdminSettingsTab(),
          ProfileTab(
            onLogout: () {
              pb.authStore.clear();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (v) => setState(() => _index = v),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: appFrontColor.value,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Einstellungen"),
        ],
      ),
    );
  }
}
