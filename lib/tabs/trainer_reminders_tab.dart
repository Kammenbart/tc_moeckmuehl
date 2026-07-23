import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class TrainerRemindersTab extends StatefulWidget {
  const TrainerRemindersTab({super.key});

  @override
  State<TrainerRemindersTab> createState() => _TrainerRemindersTabState();
}

class _TrainerRemindersTabState extends State<TrainerRemindersTab> {
  List<RecordModel> reminders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = pb.authStore.record as RecordModel;

      final result = await pb.collection('trainer_reminders').getFullList(
        filter: 'trainer = "${user.id}"',
        sort: '-created',
        expand: 'invoice,customer',
      );

      if (mounted) {
        setState(() => reminders = result);
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Mahnungen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Color _levelColor(int level) {
    switch (level) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.deepOrange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _levelLabel(int level) {
    switch (level) {
      case 1:
        return '1. Mahnung';
      case 2:
        return '2. Mahnung';
      case 3:
        return '3. Mahnung';
      default:
        return 'Mahnung';
    }
  }

  Future<void> _createReminder() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Mahnung erstellen - Feature in Entwicklung"),
      ),
    );
  }

  Future<void> _markAsResolved(RecordModel reminder) async {
    try {
      await pb.collection('trainer_reminders').update(
        reminder.id,
        body: {
          'resolved': true,
          'resolved_date': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mahnung als erledigt markiert.")),
        );
        _loadReminders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Fehler: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reminders.isEmpty
              ? const Center(
                  child: Text("Keine Mahnungen vorhanden."),
                )
              : ListView.builder(
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    final level = reminder.getIntValue('level');
                    final isResolved = reminder.getBoolValue('resolved');
                    final created = DateTime.parse(reminder.created).toLocal();
                    final invoice = reminder.expand['invoice']?[0];
                    final customer = reminder.expand['customer']?[0];
                    final amount = invoice?.getDoubleValue('total_amount') ?? 0.0;
                    final customerName = customer != null
                        ? "${customer.getStringValue('forename')} ${customer.getStringValue('surname')}"
                        : "Unbekannter Kunde";

                    return Card(
                      margin: const EdgeInsets.all(8),
                      color: isResolved ? Colors.grey[100] : null,
                      child: ListTile(
                        title: Text(
                          "€ ${amount.toStringAsFixed(2)} - $customerName",
                          style: TextStyle(
                            decoration: isResolved
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          _levelLabel(level),
                          style: TextStyle(color: _levelColor(level)),
                        ),
                        trailing: isResolved
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.green,
                                    ),
                                    onPressed: () =>
                                        _markAsResolved(reminder),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.info_outline),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            "Mahnungsdetails",
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Kunde: $customerName",
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Betrag: € ${amount.toStringAsFixed(2)}",
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Stufe: ${_levelLabel(level)}",
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Erstellt: ${DateFormat('dd.MM.yyyy', 'de_DE').format(created)}",
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text("Schließen"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appFrontColor.value,
        onPressed: _createReminder,
        child: const Icon(Icons.add),
      ),
    );
  }
}
