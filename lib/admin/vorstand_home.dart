import 'package:flutter/material.dart';
import 'package:tc_moeckmuehl/tabs/vorstand_members_tab.dart';

import '../main.dart';
import '../tabs/vorstand_dashboard_tab.dart';
import '../tabs/vorstand_news_tab.dart';
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
  int pendingMemberRequests = 0;
  List<Widget>? _memberAppBarActions;
  bool _loadedPerms = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final user = pb.authStore.record;
      if (user == null) {
        setState(() => _loadedPerms = true);
        return;
      }
      setState(() {
        final isAppAdmin = user.getBoolValue('auth_admin_app');

        // App-Admin bekommt automatisch Vollzugriff (3 = lesen+schreiben+löschen)
        memberPerm = isAppAdmin ? 3 : user.getIntValue('perm_board_member');
        kassePerm = isAppAdmin ? 3 : user.getIntValue('perm_board_cash');
        bookingPerm = isAppAdmin ? 3 : user.getIntValue('perm_board_booking');
        newsPerm = isAppAdmin ? 2 : user.getIntValue('perm_board_news');

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Die Liste der Tabs
    final tabs = [
      const VorstandDashboardTab(),
      VorstandMembersTab(
        permission: memberPerm,
        onPendingRequestsChanged: (count) {
          setState(() => pendingMemberRequests = count);
        },
        onAppBarActionsChanged: (actions) {
          setState(() => _memberAppBarActions = actions);
        },
      ),
      VorstandInvoiceTab(permission: kassePerm),
      VorstandNewsTab(permission: newsPerm),
    ];

    // Steuerung der klickbaren Bereiche
    final user = pb.authStore.record;
    if (user == null) {
      return const AuthWrapper();
    }
    final isAppAdmin = user.getBoolValue('auth_admin_app');

    final List<bool> enabled = [
      true, // Dashboard immer an
      isAppAdmin || memberPerm > 0, // Mitglieder nur bei Recht oder App-Admin
      isAppAdmin || kassePerm > 0, // Finanzen nur bei Recht oder App-Admin
      isAppAdmin || newsPerm > 0, // News nur bei Recht oder App-Admin
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Vorstand"),
        actions: _index == 1 ? _memberAppBarActions : null,
      ),

      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (v) {
          if (enabled[v]) {
            setState(() => _index = v);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Bereich gesperrt (unzureichende Rechte)"),
              ),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: appFrontColor.value,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.group,
                  color: memberPerm > 0 ? null : Colors.grey.shade400,
                ),
                if (pendingMemberRequests > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            label: "Mitglieder",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.account_balance_wallet,
              color: kassePerm > 0 ? null : Colors.grey.shade400,
            ),
            label: "Finanzen",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.newspaper,
              color: newsPerm > 0 ? null : Colors.grey.shade400,
            ),
            label: "Aktuelles",
          ),
        ],
      ),
    );
  }
}
