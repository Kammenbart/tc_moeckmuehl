import 'package:flutter/material.dart';

import '../main.dart';
import '../tabs/trainer_dashboard_tab.dart';
import '../tabs/trainer_training_tab.dart';
import '../tabs/trainer_invoice_tab.dart';
import '../tabs/trainer_dunning_tab.dart';
import '../tabs/profile_tab.dart';

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
          const TrainerDashboardTab(),
          const TrainerTrainingTab(),
          const TrainerInvoiceTab(),
          const TrainerDunningTab(),
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
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: "Training"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Rechnung"),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: "Mahnung"),
        ],
      ),
    );
  }
}
