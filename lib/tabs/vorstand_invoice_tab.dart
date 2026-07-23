import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';

class VorstandInvoiceTab extends StatefulWidget {
  final int permission; // 1: submit, 2: approve, 3: full control

  const VorstandInvoiceTab({super.key, required this.permission});

  @override
  State<VorstandInvoiceTab> createState() => _VorstandInvoiceTabState();
}

class _VorstandInvoiceTabState extends State<VorstandInvoiceTab> {
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
      String filter = '';
      final user = pb.authStore.record as RecordModel;
      final isAppAdmin = user.getBoolValue('auth_admin_app');

      if (widget.permission == 1 && !isAppAdmin) {
        // Users can only see their own invoices
        filter = 'submitted_by = "${user.id}"';
      }

      final result = await pb
          .collection('invoices')
          .getFullList(
            sort: '-created',
            filter: filter.isNotEmpty ? filter : null,
            expand: 'submitted_by',
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

  Future<void> _submitInvoice() async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    PlatformFile? selectedFile;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: const Text("Rechnung einreichen"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: "Beschreibung",
                        hintText: "z.B. Hallenmiete, Bespannung, etc.",
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: "Betrag (€)",
                        hintText: "100.50",
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("PDF-Datei"),
                          const SizedBox(height: 8),
                          if (selectedFile != null)
                            Text(
                              selectedFile!.name,
                              style: const TextStyle(color: Colors.green),
                            )
                          else
                            const Text(
                              "Keine Datei ausgewählt",
                              style: TextStyle(color: Colors.grey),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.attach_file),
                              label: const Text("PDF wählen"),
                              onPressed: () async {
                                final result = await FilePicker.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf'],
                                      allowMultiple: false,
                                    );

                                if (result != null) {
                                  setDialogState(() {
                                    selectedFile = result.files.first;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Abbrechen"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Einreichen"),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed || selectedFile == null) return;

    try {
      final user = pb.authStore.record as RecordModel;
      final amount =
          double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;

      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ungültiger Betrag"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // TODO: Upload PDF to Pocketbase files
      // For now, store metadata
      await pb
          .collection('invoices')
          .create(
            body: {
              'submitted_by': user.id,
              'description': descriptionController.text,
              'amount': amount,
              'status': 'pending', // pending, approved, rejected, paid
              'file_name': selectedFile!.name,
              'submission_date': DateTime.now().toIso8601String(),
            },
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Rechnung eingereicht.")));
        _loadInvoices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveInvoice(RecordModel invoice) async {
    try {
      await pb
          .collection('invoices')
          .update(
            invoice.id,
            body: {
              'status': 'approved',
              'approved_by': pb.authStore.record!.id,
              'approved_date': DateTime.now().toIso8601String(),
            },
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Rechnung genehmigt.")));
        _loadInvoices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectInvoice(RecordModel invoice) async {
    final noteController = TextEditingController();

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Rechnung ablehnen"),
            content: TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: "Ablehnung-Grund (optional)",
                hintText: "z.B. Rechnungsbetrag stimmt nicht",
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Ablehnen"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await pb
          .collection('invoices')
          .update(
            invoice.id,
            body: {
              'status': 'rejected',
              'rejected_by': pb.authStore.record!.id,
              'rejection_reason': noteController.text,
              'rejected_date': DateTime.now().toIso8601String(),
            },
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Rechnung abgelehnt.")));
        _loadInvoices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markAsPaid(RecordModel invoice) async {
    try {
      await pb
          .collection('invoices')
          .update(
            invoice.id,
            body: {
              'status': 'paid',
              'paid_date': DateTime.now().toIso8601String(),
            },
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rechnung als bezahlt markiert.")),
        );
        _loadInvoices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'paid':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Ausstehend';
      case 'approved':
        return 'Genehmigt';
      case 'rejected':
        return 'Abgelehnt';
      case 'paid':
        return 'Bezahlt';
      default:
        return status;
    }
  }

  List<RecordModel> _filterByStatus(String status) {
    return invoices.where((i) => i.getStringValue('status') == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = pb.authStore.record as RecordModel;
    final isAppAdmin = user.getBoolValue('auth_admin_app');
    final canSubmit = widget.permission >= 1 || isAppAdmin;
    final canApprove = widget.permission >= 2 || isAppAdmin;
    final canManage = widget.permission >= 3 || isAppAdmin;

    if (!canSubmit && !canApprove && !canManage) {
      return const Scaffold(
        body: Center(
          child: Text("Keine Berechtigung für Rechnungsverwaltung."),
        ),
      );
    }

    final pendingInvoices = _filterByStatus('pending');
    final approvedInvoices = _filterByStatus('approved');
    final rejectedInvoices = _filterByStatus('rejected');
    final paidInvoices = _filterByStatus('paid');

    final tabs = <Tab>[
      Tab(text: 'Ausstehend (${pendingInvoices.length})'),
      if (canApprove) Tab(text: 'Genehmigt (${approvedInvoices.length})'),
      if (canManage) Tab(text: 'Abgelehnt (${rejectedInvoices.length})'),
      Tab(text: 'Bezahlt (${paidInvoices.length})'),
    ];

    final tabViews = <Widget>[
      _buildInvoiceList(pendingInvoices, canApprove),
      if (canApprove) _buildInvoiceList(approvedInvoices, false),
      if (canManage) _buildInvoiceList(rejectedInvoices, false),
      _buildInvoiceList(paidInvoices, false),
    ];

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: tabs.length,
              child: Column(
                children: [
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: TabBar(
                      tabs: tabs,
                      indicatorColor: appFrontColor.value,
                      labelColor: Theme.of(context).colorScheme.onSurface,
                      unselectedLabelColor: Colors.grey,
                    ),
                  ),
                  Expanded(child: TabBarView(children: tabViews)),
                ],
              ),
            ),
      floatingActionButton: canSubmit
          ? FloatingActionButton(
              backgroundColor: appFrontColor.value,
              onPressed: _submitInvoice,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildInvoiceList(List<RecordModel> list, bool showApprovalButtons) {
    if (list.isEmpty) {
      return const Center(child: Text("Keine Rechnungen"));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final invoice = list[index];
        final created = DateTime.parse(invoice.created).toLocal();
        final status = invoice.getStringValue('status');

        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(
              "€ ${invoice.getDoubleValue('amount').toStringAsFixed(2)}",
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.getStringValue('description')),
                Text(
                  DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(created),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: Chip(
              label: Text(_statusLabel(status)),
              backgroundColor: _statusColor(status).withValues(alpha: 0.2),
              labelStyle: TextStyle(color: _statusColor(status)),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Rechnungsdetails"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Beschreibung: ${invoice.getStringValue('description')}",
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Betrag: € ${invoice.getDoubleValue('amount').toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text("Status: ${_statusLabel(status)}"),
                        const SizedBox(height: 12),
                        if (invoice
                            .getStringValue('rejection_reason')
                            .isNotEmpty)
                          Text(
                            "Ablehnungsgrund: ${invoice.getStringValue('rejection_reason')}",
                            style: const TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    if (showApprovalButtons) ...[
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _rejectInvoice(invoice);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("Ablehnen"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approveInvoice(invoice);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text("Genehmigen"),
                      ),
                    ],
                    if (status == 'approved')
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _markAsPaid(invoice);
                        },
                        child: const Text("Als bezahlt markieren"),
                      ),
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
    );
  }
}
