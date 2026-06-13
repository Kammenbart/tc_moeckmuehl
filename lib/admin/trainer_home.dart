import 'package:flutter/material.dart';

import '../main.dart';
import '../tabs/trainer_customers_tab.dart';
import '../tabs/trainer_groups_tab.dart';
import '../tabs/trainer_services_tab.dart';
import '../tabs/trainer_invoices_tab.dart';
import '../tabs/trainer_reminders_tab.dart';

class TrainerHomeScreen extends StatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer"),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const TrainerCustomersTab(),
          const TrainerGroupsTab(),
          const TrainerServicesTab(),
          const TrainerInvoicesTab(),
          const TrainerRemindersTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (v) => setState(() => _index = v),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: appFrontColor.value,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Kundenstamm"),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Gruppen"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Leistungen"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Rechnungen"),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: "Mahnungen"),
        ],
      ),
    );
  }
}
