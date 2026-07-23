import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart';
import 'trainer_portal_pages.dart';

class TrainerGroupsTab extends StatefulWidget {
  const TrainerGroupsTab({super.key});

  @override
  State<TrainerGroupsTab> createState() => _TrainerGroupsTabState();
}

class _TrainerGroupsTabState extends State<TrainerGroupsTab> with TickerProviderStateMixin {
  List<RecordModel> groups = [];
  List<RecordModel> customers = [];
  bool isLoading = true;
  late final TabController _tabController;
  List<String> _templatePreview = [];
  String _templatePreviewTitle = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGroups();
    _loadCustomers();
  }

  Future<void> _loadGroups() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = pb.authStore.record as RecordModel;
      final result = await loadTrainerGroupsSafe(user.id);

      if (mounted) {
        setState(() => groups = result);
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Gruppen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final user = pb.authStore.record as RecordModel;
      final allUsers = await pb.collection('users').getFullList(sort: 'surname,forename');
      final result = allUsers.where((customer) => _hasTrainerAssigned(customer, user.id)).toList();
      if (mounted) {
        setState(() => customers = result);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Kunden: $e');
    }
  }

  bool _hasTrainerAssigned(RecordModel user, String trainerId) {
    final raw = user.toJson()['trainer'];
    if (raw is String) {
      return raw.trim() == trainerId;
    }
    if (raw is List) {
      return raw.any((item) => item is String && item.trim() == trainerId);
    }
    if (raw is Map) {
      final value = (raw['id'] ?? raw['trainer'] ?? '').toString().trim();
      return value == trainerId;
    }
    return false;
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatInterval(String interval) {
    if (interval == '2 weekly') return 'Alle 2 Wo.';
    if (interval == 'weekly') return 'Wö.';
    return interval.isEmpty ? 'Kein Rhythmus' : interval;
  }

  Future<void> _editGroup(RecordModel? group) async {
    final isEdit = group != null;
    final nameController = TextEditingController(
      text: isEdit ? group.getStringValue('name') : '',
    );
    final costController = TextEditingController(
      text: isEdit ? group.getDoubleValue('cost').toString() : '0',
    );
    final costCenterController = TextEditingController(
      text: isEdit ? group.getIntValue('cost_center').toString() : '0',
    );
    final durationController = TextEditingController(
      text: isEdit ? group.getDoubleValue('duration').toString() : '0',
    );
    final intervalOptions = const ['weekly', '2 weekly'];
    final intervalLabels = const {'weekly': 'Wöchentlich', '2 weekly': 'Alle 2 Wochen'};
    String selectedInterval = isEdit ? group.getStringValue('interval') : 'weekly';
    selectedInterval = intervalOptions.contains(selectedInterval) ? selectedInterval : 'weekly';
    DateTime? selectedStartDate = _parseDate(group?.getStringValue('start')) ??
        _parseDate(group?.getStringValue('start_date'));
    final selectedMemberIds = <String>{
      if (isEdit) ...group.getListValue('member').cast<String?>().whereType<String>()
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Gruppe bearbeiten' : 'Neue Gruppe'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(dialogContext).size.height * 0.65,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Name der Gruppe'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: costController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Kosten'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: costCenterController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Hallenkosten'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: durationController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Dauer (Stunden)'),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: selectedInterval,
                            decoration: const InputDecoration(labelText: 'Intervall'),
                            items: intervalOptions
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(intervalLabels[value] ?? value),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedInterval = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedStartDate == null
                                      ? 'Startdatum wählen'
                                      : DateFormat('dd.MM.yyyy').format(selectedStartDate!),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: selectedStartDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => selectedStartDate = picked);
                                  }
                                },
                                child: const Text('Datum'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (customers.isEmpty)
                            const Text('Keine Kunden geladen. Bitte neu laden.')
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      showModalBottomSheet<void>(
                                        context: dialogContext,
                                        isScrollControlled: true,
                                        builder: (sheetContext) {
                                          String searchQuery = '';
                                          return StatefulBuilder(
                                            builder: (sheetContext, setSheetState) {
                                              final filteredCustomers = customers.where((customer) {
                                                final fullName =
                                                    '${customer.getStringValue('forename')} ${customer.getStringValue('surname')}'.trim();
                                                final email = customer.getStringValue('email').toLowerCase();
                                                final query = searchQuery.toLowerCase();
                                                return fullName.toLowerCase().contains(query) ||
                                                    email.contains(query);
                                              }).toList();

                                              return Container(
                                                height: MediaQuery.of(sheetContext).size.height * 0.7,
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  children: [
                                                    TextField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Mitglieder suchen...',
                                                        prefixIcon: Icon(Icons.search),
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      onChanged: (value) =>
                                                          setSheetState(() => searchQuery = value),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Expanded(
                                                      child: ListView.builder(
                                                        itemCount: filteredCustomers.length,
                                                        itemBuilder: (context, index) {
                                                          final customer = filteredCustomers[index];
                                                          final customerId = customer.id;
                                                          final fullName =
                                                              '${customer.getStringValue('forename')} ${customer.getStringValue('surname')}'.trim();
                                                          final isSelected = selectedMemberIds.contains(customerId);

                                                          return ListTile(
                                                            leading: const Icon(Icons.person),
                                                            title: Text(fullName),
                                                            subtitle: Text(customer.getStringValue('email')),
                                                            trailing: isSelected
                                                                ? const Icon(Icons.check_circle, color: Colors.green)
                                                                : const Icon(Icons.add_circle_outline),
                                                            onTap: () {
                                                              setSheetState(() {
                                                                if (isSelected) {
                                                                  selectedMemberIds.remove(customerId);
                                                                } else {
                                                                  selectedMemberIds.add(customerId);
                                                                }
                                                              });
                                                              setDialogState(() {
                                                                if (isSelected) {
                                                                  selectedMemberIds.remove(customerId);
                                                                } else {
                                                                  selectedMemberIds.add(customerId);
                                                                }
                                                              });
                                                            },
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        onPressed: () => Navigator.pop(sheetContext),
                                                        child: const Text('Fertig'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: const Text('Mitglieder auswählen'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (selectedMemberIds.isEmpty)
                                  const Text('Noch keine Mitglieder ausgewählt.')
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: selectedMemberIds.map((memberId) {
                                      final customer = customers.firstWhere(
                                        (entry) => entry.id == memberId,
                                        orElse: () => RecordModel(),
                                      );
                                      final fullName =
                                          '${customer.getStringValue('forename')} ${customer.getStringValue('surname')}'.trim();
                                      return Chip(
                                        label: Text(fullName.isEmpty ? memberId : fullName),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEdit)
                    IconButton(
                      tooltip: 'Löschen',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _deleteGroup(group);
                      },
                      icon: const Icon(Icons.delete, color: Colors.white),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Abbrechen'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _saveGroup(
                        isEdit ? group.id : null,
                        nameController.text.trim(),
                        double.tryParse(costController.text.replaceAll(',', '.')) ?? 0,
                        int.tryParse(costCenterController.text) ?? 0,
                        double.tryParse(durationController.text.replaceAll(',', '.')) ?? 0,
                        selectedMemberIds.toList(),
                        selectedStartDate,
                        selectedInterval,
                      );
                    },
                    child: const Text('Speichern'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveGroup(
    String? id,
    String name,
    double cost,
    int costCenter,
    double duration,
    List<String> memberIds,
    DateTime? startDate,
    String interval,
  ) async {
    try {
      final user = pb.authStore.record as RecordModel;
      final body = {
        'name': name.trim(),
        'trainer': user.id,
        'member': memberIds,
        'start': startDate?.toUtc().toIso8601String() ?? '',
        'interval': interval,
        'cost': cost,
        'cost_center': costCenter,
        'duration': duration,
        'end': '',
      };

      if (id != null) {
        await pb.collection('trainer_groups').update(id, body: body);
      } else {
        await pb.collection('trainer_groups').create(body: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? "Gruppe gespeichert." : "Gruppe erstellt."),
          ),
        );
        _loadGroups();
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

  Future<void> _deleteGroup(RecordModel group) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Gruppe löschen?"),
            content: Text(
              "Möchtest du die Gruppe '${group.getStringValue('name')}' wirklich löschen?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Abbrechen"),
              ),
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
      await pb.collection('trainer_groups').delete(group.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gruppe gelöscht.")),
        );
        _loadGroups();
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

  Widget _buildGroupCard(RecordModel group) {
    final startDate = _parseDate(group.getStringValue('start')) ?? _parseDate(group.getStringValue('start_date'));
    final interval = group.getStringValue('interval');
    final nextEvent = _nextOccurrence(startDate, interval);
    final cost = group.getDoubleValue('cost');
    final duration = group.getDoubleValue('duration');

    final weekdayLabel = startDate == null
        ? ''
        : DateFormat('EEE', 'de_DE').format(startDate).replaceAll('.', '').substring(0, 2);

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        onTap: () => _showGroupDetails(group),
        title: Text(
          startDate == null ? 'Gruppe ${group.id}' : 'Gruppe ${DateFormat('dd.MM.yyyy').format(startDate)}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (startDate != null)
              Text(
                '$weekdayLabel • ${_formatInterval(interval)} • € ${cost.toStringAsFixed(2)} • ${duration.toStringAsFixed(1)} h',
                style: const TextStyle(fontSize: 12),
              ),
            if (nextEvent != null)
              Text(
                'Nächster Termin: ${DateFormat('dd.MM.yyyy').format(nextEvent)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editGroup(group),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  DateTime? _nextOccurrence(DateTime? startDate, String interval) {
    if (startDate == null || interval.isEmpty) return null;
    final now = DateTime.now();
    final cycleDays = interval == '2 weekly' ? 14 : 7;
    var next = startDate;
    while (next.isBefore(now)) {
      next = next.add(Duration(days: cycleDays));
      if (next.difference(now).inDays > 365) break;
    }
    return next;
  }

  List<Map<String, dynamic>> _buildCalendarEvents() {
    final now = DateTime.now();
    final eventList = <Map<String, dynamic>>[];
    for (final group in groups) {
      final startDate = _parseDate(group.getStringValue('start')) ?? _parseDate(group.getStringValue('start_date'));
      final interval = group.getStringValue('interval');
      if (startDate == null || interval.isEmpty) continue;
      final cycleDays = interval == '2 weekly' ? 14 : 7;
      var date = startDate;
      while (date.isBefore(now.subtract(const Duration(days: 1)))) {
        date = date.add(Duration(days: cycleDays));
        if (date.difference(startDate).inDays > 365) break;
      }
      for (var i = 0; i < 12; i++) {
        if (date.isAfter(now.add(const Duration(days: 120)))) break;
        eventList.add({
          'group': group,
          'date': date,
        });
        date = date.add(Duration(days: cycleDays));
      }
    }
    eventList.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return eventList;
  }

  Widget _buildGroupsTab() {
    if (groups.isEmpty) {
      return const Center(child: Text('Keine Gruppen vorhanden.'));
    }
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupCard(group);
      },
    );
  }

  void _showGroupDetails(RecordModel group) {
    showDialog(
      context: context,
      builder: (ctx) {
        final memberIds = group.getListValue('member');
        final memberCount = memberIds.length;
        final startDate = _parseDate(group.getStringValue('start')) ?? _parseDate(group.getStringValue('start_date'));
        final cost = group.getDoubleValue('cost');
        final costCenter = group.getIntValue('cost_center');
        final duration = group.getDoubleValue('duration');
        final memberLabels = memberIds.map((memberId) {
          final matchingCustomer = customers.where((customer) => customer.id == memberId).firstOrNull;
          if (matchingCustomer != null) {
            final firstName = matchingCustomer.getStringValue('forename').trim();
            final lastName = matchingCustomer.getStringValue('surname').trim();
            return [firstName, lastName].where((value) => value.isNotEmpty).join(' ').trim();
          }
          return memberId.toString();
        }).toList();
        return AlertDialog(
          title: Text(startDate == null ? 'Gruppe ${group.id}' : 'Gruppe ${DateFormat('dd.MM.yyyy').format(startDate)}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('Intervall: ${_formatInterval(group.getStringValue('interval'))}'),
                const SizedBox(height: 8),
                Text('Kosten: € ${cost.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Kostenstelle: $costCenter'),
                const SizedBox(height: 8),
                Text('Dauer: ${duration.toStringAsFixed(1)} h'),
                const SizedBox(height: 8),
                if (startDate != null)
                  Text('Startdatum: ${DateFormat('dd.MM.yyyy').format(startDate)}'),
                const SizedBox(height: 12),
                Text('Mitglieder ($memberCount):', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (memberIds.isNotEmpty)
                  ...memberLabels.map((memberLabel) => Text(memberLabel))
                else
                  const Text('Keine Mitglieder ausgewählt.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Schließen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _editGroup(group);
              },
              child: const Text('Bearbeiten'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarTab() {
    final events = _buildCalendarEvents();
    if (events.isEmpty) {
      return const Center(child: Text('Keine Termine vorhanden.'));
    }
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final group = event['group'] as RecordModel;
        final date = event['date'] as DateTime;
        final duration = group.getDoubleValue('duration');
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('Gruppe ${group.id}'),
            subtitle: Text(
              '${DateFormat('EEEE, dd.MM.yyyy', 'de_DE').format(date)} • ${group.getStringValue('interval')}',
            ),
            trailing: Text('${duration.toStringAsFixed(1)} h'),
            onTap: () => _showGroupDetails(group),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruppen', style: TextStyle(color: Colors.white)),
        backgroundColor: appFrontColor.value,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Gruppen'),
            Tab(text: 'Kalender'),
          ],
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_templatePreview.isNotEmpty)
                    Card(
                      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: ExpansionTile(
                        title: Text('Vorlagen für $_templatePreviewTitle'),
                        subtitle: Text('${_templatePreview.length} Termine erzeugt'),
                        children: [
                          for (final item in _templatePreview)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.event_note),
                              title: Text(item),
                            ),
                          TextButton(
                            onPressed: () => setState(() {
                              _templatePreview = [];
                              _templatePreviewTitle = '';
                            }),
                            child: const Text('Vorlage ausblenden'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGroupsTab(),
                        _buildCalendarTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appFrontColor.value,
        onPressed: () => _editGroup(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
