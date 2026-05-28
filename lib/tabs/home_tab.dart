import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'profile_tab.dart';

class HomeTab extends StatefulWidget {
  final Function(DateTime) onNavigateToCourt;

  const HomeTab({super.key, required this.onNavigateToCourt});

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
      final newsRes = await pb
          .collection('news')
          .getList(page: 1, perPage: 10, sort: '-created');

      // Eigene Buchungen laden
      final bookingRes = await pb.collection('bookings').getFullList(
        filter: 'user = "${pb.authStore.record!.id}" && start_time >= "$now"',
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
    // Bankdaten-Check
    final user = pb.authStore.record as RecordModel;
    final iban = user.getStringValue('iban');
    final bic = user.getStringValue('bic');
    final bankName = user.getStringValue('bank_name');
    // bank_owner ist explizit ausgenommen

    final hasIncompleteBankData =
        iban.isEmpty || bic.isEmpty || bankName.isEmpty;

    final hasNews = news.isNotEmpty;
    final hasBookings = myBookings.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text("TC Möckmühl")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHomeData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hinweisbox für fehlende Bankdaten
                  if (hasIncompleteBankData) ...[
                    Card(
                      color: Colors.yellow.shade100,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Bankdaten unvollständig",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Bitte deine IBAN, BIC und den Banknamen im Profil ergänzen, "
                              "damit Beiträge und Abbuchungen korrekt zugeordnet werden können.",
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text("Zum Profil"),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProfileTab(
                                        onLogout: () {
                                          pb.authStore.clear();
                                          Navigator.of(context)
                                              .popUntil((r) => r.isFirst);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Aktuelles (nur wenn es Einträge gibt)
                  if (hasNews) ...[
                    const Text(
                      "Aktuelles",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: news
                            .take(4)
                            .map(
                              (n) => Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                elevation: 0,
                                child: ExpansionTile(
                                  title: Text(
                                    n.getStringValue('title'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateFormat('dd.MM.yyyy').format(
                                      DateTime.parse(n.created),
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        n.getStringValue('content'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],

                  // Meine Termine (nur wenn es Einträge gibt)
                  if (hasBookings) ...[
                    const Text(
                      "Meine Termine",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: myBookings
                            .take(4)
                            .map((b) {
                              final start = DateTime.parse(
                                      b.getStringValue('start_time'))
                                  .toLocal();
                              final court =
                                  b.expand['court']?[0].getStringValue('name') ??
                                      "Platz";
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                elevation: 0,
                                color:
                                    appFrontColor.value.withValues(alpha: 0.1),
                                child: ListTile(
                                  leading: const Icon(Icons.calendar_today),
                                  title: Text(
                                      "$court - ${DateFormat('dd.MM.').format(start)}"),
                                  subtitle: Text(
                                      "${DateFormat('HH:mm').format(start)} Uhr"),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    widget.onNavigateToCourt(start);
                                  },
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}