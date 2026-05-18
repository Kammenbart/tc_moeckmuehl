import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:tc_moeckmuehl/tabs/vorstand_members_tab.dart';

import '../main.dart';
import '../tabs/vorstand_dashboard_tab.dart';
import '../tabs/vorstand_kasse_tab.dart';
import '../tabs/vorstand_bookings_tab.dart';
import '../tabs/vorstand_notifications_tab.dart'; // Neu: Mitteilungen statt Profil

class VorstandHomeScreen extends StatefulWidget {
  const VorstandHomeScreen({super.key});

  @override
  State<VorstandHomeScreen> createState() => _VorstandHomeScreenState();
}

class _VorstandHomeScreenState extends State<VorstandHomeScreen> {
  int _index = 0;
  int memberPerm = 0;
  int kassePerm = 0;
  int bookingPerm = 0;
  bool _loadedPerms = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final user = pb.authStore.model as RecordModel;
      setState(() {
        // Lädt die Rechte aus deiner PocketBase Users-Collection
        memberPerm = user.getIntValue('perm_vorstand_member');
        kassePerm = user.getIntValue('perm_vorstand_kasse');
        bookingPerm = user.getIntValue('perm_vorstand_booking');
        _loadedPerms = true;
      });
    } catch (e) {
      debugPrint("Fehler beim Laden der Rechte: $e");
      setState(() => _loadedPerms = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedPerms) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Die Liste der Tabs (Profil wurde durch Notifications ersetzt)
    final tabs = [
      const VorstandDashboardTab(),
      VorstandMembersTab(permission: memberPerm),
      VorstandKasseTab(permission: kassePerm),
      VorstandBookingsTab(permission: bookingPerm),
      const VorstandNotificationsTab(), // Hier werden die Anfragen angezeigt
    ];

    // Steuerung der klickbaren Bereiche
    final List<bool> enabled = [
      true,              // Dashboard immer an
      memberPerm > 0,    // Mitglieder nur bei Recht
      kassePerm > 0,     // Kasse nur bei Recht
      bookingPerm > 0,   // Buchungen nur bei Recht
      true,              // Mitteilungen immer an
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Vorstand"),
      ),


      body: IndexedStack(
        index: _index,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (v) {
          if (enabled[v]) {
            setState(() => _index = v);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Bereich gesperrt (unzureichende Rechte)")),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: appFrontColor.value,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard), 
            label: "Dashboard"
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group, color: memberPerm > 0 ? null : Colors.grey.shade400),
            label: "Mitglieder",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet, color: kassePerm > 0 ? null : Colors.grey.shade400),
            label: "Kasse",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event, color: bookingPerm > 0 ? null : Colors.grey.shade400),
            label: "Buchungen",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications), 
            label: "Mitteilungen"
          ),
        ],
      ),
    );
  }
}
