import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class TrainerInvoicesTab extends StatefulWidget {
  const TrainerInvoicesTab({super.key});

  @override
  State<TrainerInvoicesTab> createState() => _TrainerInvoicesTabState();
}

class _TrainerInvoicesTabState extends State<TrainerInvoicesTab> {
  List<RecordModel> invoices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = pb.authStore.record as RecordModel;

      final result = await pb.collection('trainer_invoices').getFullList(
        filter: 'trainer = "${user.id}"',
        sort: '-created',
        expand: 'customer,items',
      );

      if (mounted) {
        setState(() => invoices = result);
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Rechnungen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _createInvoice() async {
    // Simplified invoice creation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Invoice creation feature coming soon"),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Entwurf';
      case 'sent':
        return 'Versendet';
      case 'paid':
        return 'Bezahlt';
      case 'overdue':
        return 'Überfällig';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rechnungen"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : invoices.isEmpty
              ? const Center(
                  child: Text("Keine Rechnungen vorhanden."),
                )
              : ListView.builder(
                  itemCount: invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = invoices[index];
                    final created = DateTime.parse(invoice.created).toLocal();
                    final status = invoice.getStringValue('status');
                    final amount = invoice.getDoubleValue('total_amount');
                    final customer = invoice.expand['customer']?[0];
                    final customerName = customer != null
                        ? "${customer.getStringValue('forename')} ${customer.getStringValue('surname')}"
                        : "Unbekannter Kunde";

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text("€ ${amount.toStringAsFixed(2)} - $customerName"),
                        subtitle: Text(
                          DateFormat('dd.MM.yyyy', 'de_DE').format(created),
                        ),
                        trailing: Chip(
                          label: Text(_statusLabel(status)),
                          backgroundColor:
                              _statusColor(status).withValues(alpha: 0.2),
                          labelStyle: TextStyle(color: _statusColor(status)),
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Rechnungsdetails"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Kunde: $customerName"),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Betrag: € ${amount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text("Status: ${_statusLabel(status)}"),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Schließen"),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appFrontColor.value,
        onPressed: _createInvoice,
        child: const Icon(Icons.add),
      ),
    );
  }
}
