import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:tc_moeckmuehl/tabs/vorstand_members_tab.dart';

import '../main.dart';
import '../tabs/vorstand_dashboard_tab.dart';
import '../tabs/vorstand_kasse_tab.dart';
import '../tabs/vorstand_bookings_tab.dart';
import '../tabs/vorstand_notifications_tab.dart';
import '../tabs/vorstand_news_tab.dart';
import '../tabs/vorstand_membership_tab.dart';
import '../tabs/vorstand_invoice_tab.dart';

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
  int newsPerm = 0;
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
          final isAppAdmin = user.getBoolValue('auth_admin_app');

          // App-Admin bekommt automatisch Vollzugriff (3 = lesen+schreiben+löschen)
          memberPerm  = isAppAdmin ? 3 : user.getIntValue('perm_board_member');
          kassePerm   = isAppAdmin ? 3 : user.getIntValue('perm_board_cash');
          bookingPerm = isAppAdmin ? 3 : user.getIntValue('perm_board_booking');
          newsPerm    = isAppAdmin ? 2 : user.getIntValue('perm_board_news');

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

    // Die Liste der Tabs
    final tabs = [
      const VorstandDashboardTab(),
      VorstandMembersTab(permission: memberPerm),
      VorstandMembershipTab(permission: memberPerm),
      VorstandKasseTab(permission: kassePerm),
      VorstandInvoiceTab(permission: kassePerm),
      VorstandBookingsTab(permission: bookingPerm),
      VorstandNewsTab(permission: newsPerm),
      const VorstandNotificationsTab(),
    ];

    // Steuerung der klickbaren Bereiche
    final user = pb.authStore.model as RecordModel;
    final isAppAdmin = user.getBoolValue('auth_admin_app');

    final List<bool> enabled = [
      true,                        // Dashboard immer an
      isAppAdmin || memberPerm > 0,   // Mitglieder nur bei Recht oder App-Admin
      isAppAdmin || memberPerm >= 3,  // Mitgliedschaften verwalten nur bei Recht >= 3
      isAppAdmin || kassePerm > 0,    // Kasse nur bei Recht oder App-Admin
      isAppAdmin || kassePerm > 0,    // Rechnungen nur bei Kasse-Recht
      isAppAdmin || bookingPerm > 0,  // Buchungen nur bei Recht oder App-Admin
      isAppAdmin || newsPerm > 0,     // News nur bei Recht oder App-Admin
      true,                           // Mitteilungen immer an
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
            icon: Icon(Icons.person_add, color: memberPerm >= 3 ? null : Colors.grey.shade400),
            label: "Bewerbungen",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet, color: kassePerm > 0 ? null : Colors.grey.shade400),
            label: "Kasse",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt, color: kassePerm > 0 ? null : Colors.grey.shade400),
            label: "Rechnungen",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event, color: bookingPerm > 0 ? null : Colors.grey.shade400),
            label: "Buchungen",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.newspaper, color: newsPerm > 0 ? null : Colors.grey.shade400),
            label: "Aktuelles",
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
