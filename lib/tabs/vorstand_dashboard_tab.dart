import 'package:flutter/material.dart';
import '../main.dart';

class VorstandDashboardTab extends StatefulWidget {
  const VorstandDashboardTab({super.key});

  @override
  State<VorstandDashboardTab> createState() => _VorstandDashboardTabState();
}

class _VorstandDashboardTabState extends State<VorstandDashboardTab> {
  int memberCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final result = await pb.collection('users').getList(page: 1, perPage: 1);
      setState(() {
        memberCount = result.totalItems;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fehler Dashboard: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Übersicht", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.group, size: 40, color: Colors.green),
                title: const Text("Mitglieder aktuell"),
                trailing: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text("$memberCount", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
