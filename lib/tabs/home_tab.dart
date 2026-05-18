import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToCourt; // 1. Variable definieren

  const HomeTab({super.key, required this.onNavigateToCourt}); // 2. Im Konstruktor verlangen

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<RecordModel> news = [];
  List<RecordModel> myBookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      
      // News laden
      final newsRes = await pb.collection('news').getList(page: 1, perPage: 10, sort: '-created');
      
      // Eigene Buchungen laden
      final bookingRes = await pb.collection('bookings').getFullList(
        filter: 'user = "${pb.authStore.model!.id}" && start_time >= "$now"',
        sort: 'start_time',
        expand: 'court',
      );

      if (mounted) {
        setState(() {
          news = newsRes.items;
          myBookings = bookingRes;
        });
      }
    } catch (e) {
      debugPrint("Fehler News/Buchungen: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TC Möckmühl News")),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadHomeData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("Aktuelles", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...news.map((n) => Card(
                  child: ExpansionTile(
                    title: Text(n.getStringValue('title'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(n.created))),
                    children: [Padding(padding: const EdgeInsets.all(16.0), child: Text(n.getStringValue('content')))],
                  ),
                )),
                const SizedBox(height: 25),
                const Text("Meine Termine", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...myBookings.map((b) {
                  final start = DateTime.parse(b.getStringValue('start_time')).toLocal();
                  final court = b.expand['court']?[0].getStringValue('name') ?? "Platz";
                  return Card(
                    color: appFrontColor.value.withOpacity(0.1),
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text("$court - ${DateFormat('dd.MM.').format(start)}"),
                      subtitle: Text("${DateFormat('HH:mm').format(start)} Uhr"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: widget.onNavigateToCourt, // Hier wird die Funktion aufgerufen
                    ),
                  );
                }),
              ],
            ),
          ),
    );
  }
}
