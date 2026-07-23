import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart';

class TrainerServicesTab extends StatefulWidget {
  const TrainerServicesTab({super.key});

  @override
  State<TrainerServicesTab> createState() => _TrainerServicesTabState();
}

class _TrainerServicesTabState extends State<TrainerServicesTab> {
  List<RecordModel> services = [];
  List<RecordModel> trainingUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadTrainingUsers();
  }

  /// Konvertiert Double (1.5) zu H:MM Format (1:30)
  String _durationToFormat(dynamic value) {
    if (value == null) return "0:00";
    double hours = (value is int) ? value.toDouble() : (value as double? ?? 0.0);
    int h = hours.toInt();
    int m = ((hours - h) * 60).toInt();
    return "$h:${m.toString().padLeft(2, '0')}";
  }

  /// Konvertiert H:MM Format (1:30) zu Double (1.5)
  double _formatToDuration(String format) {
    if (!format.contains(':')) return 0.0;
    List<String> parts = format.split(':');
    int h = int.tryParse(parts[0]) ?? 0;
    int m = int.tryParse(parts[1]) ?? 0;
    return h + (m / 60);
  }

  /// Konvertiert Share zu Prozentsatz (0.3333 → 33,33)
  String _shareToPercent(dynamic value) {
    if (value == null) return "0";
    double share = (value is int) ? value.toDouble() : (value as double? ?? 0.0);
    return "${(share * 100).toStringAsFixed(2)}";
  }

  /// Konvertiert Prozentsatz zu Share (33,33 → 0.3333)
  double _percentToShare(String percent) {
    double p = double.tryParse(percent.replaceAll('%', '').replaceAll(',', '.')) ?? 0.0;
    return p / 100;
  }

  Future<void> _loadServices() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = pb.authStore.record as RecordModel;

      final result = await pb.collection('trainer_services').getFullList(
        filter: "trainer = '${user.id}'",
        sort: 'date',
      );

      if (mounted) {
        setState(() => services = result);
      }
    } catch (e) {
      debugPrint("✗ Fehler beim Laden: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadTrainingUsers() async {
    try {
      final result = await pb.collection('users').getFullList(
        sort: 'surname,forename',
      );
      if (mounted) {
        setState(() => trainingUsers = result.where((user) => user.getBoolValue('training')).toList());
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Training-Benutzer: $e');
    }
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  String _formatDateForDisplay(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  void _pickCustomer(
    List<RecordModel> users,
    String currentCustomerId,
    Function(String, String) onPick,
  ) {
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredUsers = users.where((u) {
            final fullName =
                '${u.getStringValue('forename')} ${u.getStringValue('surname')}'.trim();
            final matchesSearch = fullName.toLowerCase().contains(searchQuery.toLowerCase());
            return matchesSearch;
          }).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Kunde suchen...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setSheetState(() => searchQuery = value),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, i) {
                      final userRecord = filteredUsers[i];
                      final userId = userRecord.id;
                      final fullName =
                          '${userRecord.getStringValue('forename')} ${userRecord.getStringValue('surname')}'.trim();
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(fullName),
                        subtitle: Text(userId),
                        selected: userId == currentCustomerId,
                        onTap: () {
                          onPick(userId, fullName);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editService(RecordModel? service) async {
    final isEdit = service != null;
    final serviceController = TextEditingController(
      text: isEdit ? service.getStringValue('service') : '',
    );
    final durationController = TextEditingController(
      text: isEdit ? _durationToFormat(service.toJson()['duration']) : '0:00',
    );
    final costController = TextEditingController(
      text: isEdit ? (service.toJson()['cost']?.toString() ?? '0') : '0',
    );
    final shareController = TextEditingController(
      text: isEdit ? _shareToPercent(service.toJson()['share']) : '100',
    );

    String selectedTrainerId = '';
    String selectedTrainerName = '';
    String selectedCustomerId = '';
    String selectedCustomerName = '';
    DateTime selectedDateTime = DateTime.now();

    if (isEdit) {
      final user = pb.authStore.record as RecordModel;
      selectedTrainerId = user.id;
      selectedTrainerName = '${user.getStringValue('forename')} ${user.getStringValue('surname')}';
      
      if (service.toJson()['customer']?.toString().isNotEmpty ?? false) {
        selectedCustomerId = service.getStringValue('customer');
        try {
          final customerRecord = await pb.collection('users').getOne(selectedCustomerId);
          selectedCustomerName = '${customerRecord.getStringValue('forename')} ${customerRecord.getStringValue('surname')}';
        } catch (e) {
          selectedCustomerName = selectedCustomerId;
        }
      }

      final dateStr = service.getStringValue('date');
      try {
        selectedDateTime = DateTime.parse(dateStr);
      } catch (e) {
        selectedDateTime = DateTime.now();
      }
    }

    String selectedPresence = isEdit ? service.getStringValue('presence') : 'present';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.all(16),
          title: Text(isEdit ? "Leistung bearbeiten" : "Neue Leistung hinzufügen"),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Service (Beschreibung)
                  TextField(
                    controller: serviceController,
                    decoration: InputDecoration(
                      labelText: "Leistung",
                      hintText: "z.B. Tennis Training",
                      prefixIcon: const Icon(Icons.sports_tennis),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Trainer (readonly - current user)
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Trainer",
                      prefixIcon: const Icon(Icons.person_pin),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      selectedTrainerName.isNotEmpty ? selectedTrainerName : 'Trainer',
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Kunde (selectable with bottom sheet)
                  InkWell(
                    onTap: () {
                      _pickCustomer(
                        trainingUsers,
                        selectedCustomerId,
                        (customerId, customerName) {
                          setDialogState(() {
                            selectedCustomerId = customerId;
                            selectedCustomerName = customerName;
                          });
                        },
                      );
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "Kunde",
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        selectedCustomerName.isNotEmpty
                            ? selectedCustomerName
                            : 'Kunde wählen',
                        style: const TextStyle(fontSize: 16, color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Datum-Auswahl
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDateTime = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selectedDateTime.hour,
                            selectedDateTime.minute,
                          );
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "Datum",
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _formatDateTime(selectedDateTime),
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Dauer & Kosten
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationController,
                          decoration: InputDecoration(
                            labelText: "Dauer",
                            hintText: "H:MM (z.B. 1:30)",
                            prefixIcon: const Icon(Icons.schedule),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: costController,
                          decoration: InputDecoration(
                            labelText: "Kosten",
                            hintText: "€",
                            prefixIcon: const Icon(Icons.euro),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Anteil & Presence
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: shareController,
                          decoration: InputDecoration(
                            labelText: "Anteil",
                            hintText: "z.B.0,5",
                            prefixIcon: const Icon(Icons.percent),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedPresence.isEmpty ? '' : selectedPresence,
                          decoration: InputDecoration(
                            labelText: "Anwesenheit",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('Keine Auswahl')),
                            DropdownMenuItem(value: 'present', child: Text('Anwesend')),
                            DropdownMenuItem(value: 'absent', child: Text('Abwesend')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedPresence = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveService(
                  isEdit ? service.id : null,
                  serviceController.text,
                  durationController.text,
                  costController.text,
                  shareController.text,
                  selectedDateTime,
                  selectedCustomerId,
                  selectedPresence,
                );
              },
              icon: const Icon(Icons.save),
              label: const Text("Speichern"),
              style: ElevatedButton.styleFrom(
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveService(
    String? id,
    String service,
    String duration,
    String cost,
    String share,
    DateTime dateTime,
    String customerId,
    String presence,
  ) async {
    try {
      final user = pb.authStore.record as RecordModel;
      final durationDouble = _formatToDuration(duration);
      final costInt = int.tryParse(cost) ?? 0;
      final shareDouble = _percentToShare(share);

      final body = {
        'service': service,
        'duration': durationDouble,
        'cost': costInt,
        'share': shareDouble,
        'date': dateTime.toIso8601String(),
        'customer': customerId.isNotEmpty ? customerId : null,
        'presence': presence,
        'trainer': user.id,
      };

      if (id != null) {
        await pb.collection('trainer_services').update(id, body: body);
      } else {
        await pb.collection('trainer_services').create(body: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? "✓ Leistung aktualisiert" : "✓ Leistung erstellt"),
            backgroundColor: Colors.green,
          ),
        );
        _loadServices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }


  Future<void> _deleteService(RecordModel service) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Leistung löschen?"),
            content: Text(
              "Möchtest du '${service.getStringValue('service')}' wirklich löschen?",
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Abbrechen")),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Löschen"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await pb.collection('trainer_services').delete(service.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✓ Leistung gelöscht"), backgroundColor: Colors.green),
        );
        _loadServices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : services.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_note, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "Keine Leistungen vorhanden",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text("Füge deine erste Leistung hinzu!", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final isPresent = service.getStringValue('presence') == 'present';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                appFrontColor.value.withOpacity(0.05),
                                appFrontColor.value.withOpacity(0.02),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Header: Service Name + Presence Badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        service.getStringValue('service'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPresent ? Colors.green[100] : Colors.red[100],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isPresent ? "✓ Anwesend" : "✗ Abwesend",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isPresent ? Colors.green[800] : Colors.red[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),

                                // Infos Grid
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildInfoRow(
                                      "💰 Kosten",
                                      "€ ${(service.toJson()['cost'] ?? 0).toStringAsFixed(2).replaceAll('.', ',')}",
                                    ),
                                    _buildInfoRow(
                                      "⏱️  Dauer",
                                      _durationToFormat(service.toJson()['duration']),
                                    ),
                                    _buildInfoRow(
                                      "📊 Anteil",
                                      _shareToPercent(service.toJson()['share']).replaceAll('%', ''),
                                    ),
                                    _buildInfoRow(
                                      "📅 Datum",
                                      _formatDateForDisplay(service.getStringValue('date')),
                                    ),
                                    if (service.toJson()['invoice'] != null && service.toJson()['invoice'].toString().isNotEmpty)
                                      _buildInfoRow(
                                        "📄 Rechnung",
                                        "${service.toJson()['invoice'].toString().substring(0, 8)}...",
                                      )
                                    else
                                      _buildInfoRow(
                                        "📄 Rechnung",
                                        "Keine Rechnung",
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),

                                // Action Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _editService(service),
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text("Bearbeiten"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: appFrontColor.value,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _deleteService(service),
                                      icon: const Icon(Icons.delete, size: 18),
                                      label: const Text("Löschen"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[400],
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appFrontColor.value,
        foregroundColor: Colors.white,
        onPressed: () => _editService(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
