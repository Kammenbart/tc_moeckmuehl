import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class DrinkTab extends StatelessWidget {
  const DrinkTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Getränkekasse"),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: "Eigenen Artikel buchen",
              onPressed: () async {
                await _showCustomDrinkDialog(context);
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Buchen"),
              Tab(text: "Verlauf"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DrinkBookingView(),
            DrinkHistoryView(),
          ],
        ),
      ),
    );
  }
  Future<void> _showCustomDrinkDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    int count = 1;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text("Eigenen Artikel buchen"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Artikelname",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Preis (€)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Anzahl:"),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              count = (count - 1).clamp(1, 99);
                            });
                          },
                        ),
                        Text("$count"),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              count = count + 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Abbrechen"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final priceStr = priceController.text.trim();
                    final price = double.tryParse(
                          priceStr.replaceAll(',', '.'),
                        ) ??
                        0;

                    if (name.isEmpty || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Bitte Artikelname und gültigen Preis eingeben."),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      await pb.collection('beverage_orders').create(body: {
                        "user": pb.authStore.model.id,
                        "count": count,
                        "cancel_requested": false,
                        "custom_name": name,
                        "custom_price": price,
                      });

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Eigener Artikel gebucht."),
                          ),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Fehler: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text("Buchen"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
// --- Unter-Seite 1: Buchen ---
class DrinkBookingView extends StatefulWidget {
  const DrinkBookingView({super.key});
  @override
  State<DrinkBookingView> createState() => _DrinkBookingViewState();
}

class _DrinkBookingViewState extends State<DrinkBookingView> {
  List<RecordModel> drinks = [];
  Map<String, int> counts = {};
  Map<String, double> prices = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await pb.collection('beverages').getFullList(sort: 'name');
    setState(() {
      drinks = res;
      counts.clear();
      prices.clear();
      for (var d in res) {
        counts[d.id] = 0;
        prices[d.id] = d.getDoubleValue('price');
      }
    });
  }

  double _currentTotal() {
    double sum = 0;
    counts.forEach((id, qty) {
      final price = prices[id] ?? 0;
      sum += price * qty;
    });
    return sum;
  }

    @override
  Widget build(BuildContext context) {
    final total = _currentTotal();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: drinks.length,
            itemBuilder: (context, i) {
              final d = drinks[i];
              final id = d.id;
              final price = prices[id] ?? 0;
              final qty = counts[id] ?? 0;

              return ListTile(
                title: Text(d.getStringValue('name')),
                subtitle: Text("${price.toStringAsFixed(2)} €"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        setState(() {
                          final current = counts[id] ?? 0;
                          counts[id] = (current - 1).clamp(0, 99);
                        });
                      },
                    ),
                    Text(
                      "$qty",
                      style: const TextStyle(fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          final current = counts[id] ?? 0;
                          counts[id] = current + 1;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: appBackColor.value.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summe der aktuell ausgewählten Getränke
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Aktuelle Auswahl:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${total.toStringAsFixed(2)} €",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: appFrontColor.value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Info-Feld "Eigene Buchungen" (Summe aller bisherigen Bestellungen)
              FutureBuilder(
                future: _loadMyTotal(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final myTotal = snapshot.data as double;
                  return Text(
                    "Eigene gebuchte Getränke insgesamt: ${myTotal.toStringAsFixed(2)} €",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  );
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: total == 0
                    ? null
                    : () async {
                        for (var id in counts.keys) {
                          final qty = counts[id] ?? 0;
                          if (qty > 0) {
                            await pb.collection('beverage_orders').create(
                              body: {
                                "user": pb.authStore.model.id,
                                "beverage": id,
                                "count": qty,
                                "cancel_requested": false,
                              },
                            );
                          }
                        }
                        setState(() {
                          counts.updateAll((key, value) => 0);
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Buchung erfolgreich!")),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appFrontColor.value,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text("Verbindlich buchen"),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Future<double> _loadMyTotal() async {
    final userId = pb.authStore.model.id;
    final orders = await pb.collection('beverage_orders').getFullList(
      filter: 'user = "$userId"',
      expand: 'beverage',
    );
    double sum = 0;
    for (var o in orders) {
      final bev = o.expand['beverage']?[0];
      if (bev == null) continue;
      final price = bev.getDoubleValue('price');
      final count = o.getIntValue('count');
      sum += price * count;
    }
    return sum;
  }
}

// --- Unter-Seite 2: Verlauf ---
class DrinkHistoryView extends StatefulWidget {
  const DrinkHistoryView({super.key});

  @override
  State<DrinkHistoryView> createState() => _DrinkHistoryViewState();
}

class _DrinkHistoryViewState extends State<DrinkHistoryView> {
  List<RecordModel> orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final userId = pb.authStore.model.id;

    try {
      final res = await pb.collection('beverage_orders').getFullList(
            filter: 'user = "$userId"',
            expand: 'beverage',
            sort: '-created',
          );
      setState(() {
        orders = res;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _total() {
    double total = 0;
    for (var o in orders) {
      final bev = o.expand['beverage']?[0];
      if (bev == null) continue;
      final price = bev.getDoubleValue('price');
      final count = o.getIntValue('count');
      total += price * count;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return const Center(
        child: Text("Noch keine Getränke gebucht."),
      );
    }

    final total = _total();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              final bev = o.expand['beverage']?[0];
              final customName = o.getStringValue('custom_name');
              final hasCustom = bev == null && customName.isNotEmpty;
              final name = hasCustom
                  ? customName
                  : (bev?.getStringValue('name') ?? "Unbekannt");
              final price = hasCustom
                  ? o.getDoubleValue('custom_price')
                  : (bev?.getDoubleValue('price') ?? 0);
              final count = o.getIntValue('count');
              final created =
                  DateTime.parse(o.getStringValue('created')).toLocal();
              final createdStr = DateFormat(
                'EEEE, dd.MM.yyyy HH:mm',
                'de_DE',
              ).format(created);

              final canCancelDirect =
                  DateTime.now().difference(created) <=
                      const Duration(minutes: 5);
              final cancelRequested =
                  o.getBoolValue('cancel_requested');

              final lineTotal = price * count;

              return Card(
                child: ListTile(
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(createdStr),
                      Text(
                        "${count}x à ${price.toStringAsFixed(2)} € = ${lineTotal.toStringAsFixed(2)} €",
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (cancelRequested)
                        const Text(
                          "Stornierung angefragt",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (canCancelDirect && !cancelRequested)
                        TextButton(
                          onPressed: () async {
                            try {
                              // Infos für Notification sammeln
                              final bev = o.expand['beverage']?[0];
                              final articleName = bev?.getStringValue('name') ?? "Unbekanntes Getränk";

                              final userRec = pb.authStore.model as RecordModel;
                              final personName = [
                                userRec.getStringValue('forename'),
                                userRec.getStringValue('surname'),
                              ].where((e) => e.isNotEmpty).join(' ');
                              final dateStr = DateFormat('dd.MM.yyyy', 'de_DE').format(DateTime.now());

                              await pb
                                  .collection('beverage_orders')
                                  .delete(o.id);

                              // Notification für direkte Stornierung
                              await pb.collection('notifications').create(body: {
                                "message":
                                    "Artikel $articleName wurde von $personName am $dateStr storniert.",
                                "category": "info",
                                "priority": "normal",
                              });

                              setState(() {
                                orders.removeAt(i);
                              });
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Storno fehlgeschlagen: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text("Stornieren"),
                        )
                    else if (!cancelRequested)
                      TextButton(
                        onPressed: () async {
                          try {
                            final bev = o.expand['beverage']?[0];
                            final articleName = bev?.getStringValue('name') ?? "Unbekanntes Getränk";
                            final userRec = pb.authStore.model as RecordModel;
                            final personName = [
                              userRec.getStringValue('forename'),
                              userRec.getStringValue('surname'),
                            ].where((e) => e.isNotEmpty).join(' ');
                            final dateStr = DateFormat('dd.MM.yyyy', 'de_DE').format(DateTime.now());
                            await pb.collection('beverage_orders').update(
                              o.id,
                              body: {
                                "cancel_requested": true,
                              },
                            );
                            // Notification für Storno-Anfrage
                            await pb.collection('notifications').create(body: {
                              "message":
                                  "Für Artikel $articleName wurde von $personName am $dateStr eine Stornierung angefragt.",
                              "category": "action_required",
                              "priority": "normal",
                            });
                            await _load(); // Liste neu laden
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Storno-Anfrage fehlgeschlagen: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: appFrontColor.value,
                        ),
                        child: const Text("Storno anfragen"),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: appBackColor.value.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Gesamtsumme aller Buchungen:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "${total.toStringAsFixed(2)} €",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: appFrontColor.value,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}