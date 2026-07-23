import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../main.dart';
import '../services/settings_service.dart';
import '../services/email_service.dart';
import '../services/notification_workflow_service.dart';
import 'profile_tab.dart';
import 'vorstand_invoice_tab.dart';

class MoreMenuTab extends StatelessWidget {
  const MoreMenuTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menü'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Zusätzliche Funktionen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            icon: Icons.person,
            title: 'Profil',
            subtitle: 'Persönliche Daten ansehen & bearbeiten',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileTab(
                    onLogout: () {
                      pb.authStore.clear();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                ),
              );
            },
          ),
          _MenuTile(
            icon: Icons.schedule,
            title: 'Arbeitsdienste',
            subtitle: 'Dienste ausschreiben, annehmen und anfragen',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkServicesPage()),
              );
            },
          ),
          _MenuTile(
            icon: Icons.lightbulb,
            title: 'Verbesserungsvorschläge',
            subtitle: 'Feedback an den Vorstand senden',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FeedbackPage()),
              );
            },
          ),
          _MenuTile(
            icon: Icons.receipt_long,
            title: 'Rechnungen / Belege einreichen',
            subtitle: 'Kostenbelege einfach hochladen',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const VorstandInvoiceTab(permission: 1),
                ),
              );
            },
          ),
          _MenuTile(
            icon: Icons.group,
            title: 'Mitgliedschaftsinfo / Anfrage',
            subtitle: 'Status prüfen & Mitgliedschaft anfragen',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MembershipInfoPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: appFrontColor.value),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

enum WorkCreateMode { eintragen, ausschreiben }

class WorkServicesPage extends StatefulWidget {
  const WorkServicesPage({super.key});

  @override
  State<WorkServicesPage> createState() => _WorkServicesPageState();
}

class _WorkServicesPageState extends State<WorkServicesPage> {
  bool isLoading = true;
  List<RecordModel> workItems = [];
  List<RecordModel> myAcceptedAnnouncements = [];
  List<RecordModel> myPendingRequests = [];
  List<RecordModel> myCompletedWorkItems = [];
  List<RecordModel> approvalRequests = [];
  bool canApprove = false;
  bool canChooseMode = false;
  late RecordModel user;

  @override
  void initState() {
    super.initState();
    _loadWorkItems();
  }

  Future<void> _loadWorkItems() async {
    setState(() => isLoading = true);
    try {
      user = pb.authStore.record as RecordModel;
      final isAppAdmin = user.getBoolValue('auth_admin_app');
      final permWork = isAppAdmin ? 2 : user.getIntValue('perm_board_work');
      canApprove = isAppAdmin || permWork >= 1;
      canChooseMode = isAppAdmin || permWork >= 2;

      final items = await pb.collection('work').getFullList(
            sort: 'date',
            expand: 'assumed_by,approved_by,created_by',
          );
      final myId = user.id;

      final openItems = items.where((item) {
        return item.getStringValue('state') == 'open';
      }).toList();

      final assumedItems = items.where((item) {
        return item.getStringValue('state') == 'assumed';
      }).toList();

      final approvedItems = items.where((item) {
        return item.getStringValue('state') == 'approved';
      }).toList();

      final myAccepted = assumedItems.where((item) {
        final assumed = List<String>.from(item.getListValue('assumed_by').cast<String>());
        return assumed.contains(myId);
      }).toList();

      final myPending = openItems.where((item) {
        return item.getStringValue('created_by') == myId;
      }).toList();

      final myCompleted = approvedItems.where((item) {
        final assumed = List<String>.from(item.getListValue('assumed_by').cast<String>());
        return assumed.contains(myId) || item.getStringValue('created_by') == myId;
      }).toList();

      if (mounted) {
        setState(() {
          workItems = openItems;
          myAcceptedAnnouncements = myAccepted;
          myPendingRequests = myPending;
          myCompletedWorkItems = myCompleted;
          approvalRequests = openItems;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Arbeitsdienste: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Arbeitsdienste: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleAssumption(RecordModel item) async {
    final myId = user.id;
    final assumed = List<String>.from(item.getListValue('assumed_by').cast<String>());
    final isAssigned = assumed.contains(myId);
    if (isAssigned) {
      assumed.remove(myId);
    } else {
      if (assumed.length >= item.getIntValue('persons_required')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dieser Dienst ist bereits voll belegt.'),
            ),
          );
        }
        return;
      }
      assumed.add(myId);
    }

    try {
      final currentState = item.getStringValue('state');
      final nextState = assumed.isEmpty ? 'open' : 'assumed';
      if (currentState == 'approved') {
        return;
      }
      await pb.collection('work').update(item.id, body: {
        'assumed_by': assumed,
        'state': nextState,
      });
      await _loadWorkItems();
    } catch (e) {
      debugPrint('Fehler beim Aktualisieren der Übernahme: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveRequest(RecordModel item) async {
    try {
      await pb.collection('work').update(item.id, body: {
        'approved_by': user.id,
        'state': 'approved',
      });
      await _loadWorkItems();
    } catch (e) {
      debugPrint('Fehler beim Genehmigen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest(RecordModel item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Anfrage ablehnen'),
            content: const Text('Soll diese Arbeitsdienst-Anfrage wirklich gelöscht werden?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Löschen'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await pb.collection('work').delete(item.id);
      await _loadWorkItems();
    } catch (e) {
      debugPrint('Fehler beim Löschen der Anfrage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showCreateDialog(WorkCreateMode mode) async {
    final isAppAdmin = user.getBoolValue('auth_admin_app');
    final permWork = isAppAdmin ? 2 : user.getIntValue('perm_board_work');
    final canChooseMode = isAppAdmin || permWork >= 2;
    if (mode == WorkCreateMode.ausschreiben && !canChooseMode) {
      mode = WorkCreateMode.eintragen;
    }

    final nameController = TextEditingController();
    final hoursController = TextEditingController();
    final personsController = TextEditingController();
    final List<String> helperNames = [];
    DateTime? selectedDate;

    final title = mode == WorkCreateMode.eintragen
        ? 'Dienst eintragen'
        : 'Dienst ausschreiben';
    final isEntryMode = mode == WorkCreateMode.eintragen;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Bezeichnung',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isEntryMode) ...[
                      TextField(
                        controller: hoursController,
                        decoration: const InputDecoration(
                          labelText: 'geleistete Stunden',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final users = await pb.collection('users').getFullList(sort: 'surname');
                          await _pickHelper(users, helperNames, setDialogState);
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Helfer hinzufügen'),
                      ),
                      const SizedBox(height: 8),
                      if (helperNames.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: helperNames
                              .map(
                                (name) => Chip(
                                  label: Text(name),
                                  onDeleted: () => setDialogState(
                                    () => helperNames.remove(name),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ] else ...[
                      TextField(
                        controller: hoursController,
                        decoration: const InputDecoration(
                          labelText: 'Geschätze Stunden',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: personsController,
                        decoration: const InputDecoration(labelText: 'Anzahl Personen'),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Datum & Uhrzeit'),
                      subtitle: Text(selectedDate == null
                          ? (isEntryMode ? 'Noch nicht ausgewählt' : 'Optional')
                          : DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(selectedDate!.toLocal())),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final dialogContext = ctx;
                          final date = await showDatePicker(
                            context: dialogContext,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            locale: const Locale('de', 'DE'),
                          );
                          if (date == null) return;
                          if (!mounted) return;
                          final time = await showTimePicker(
                            // ignore: use_build_context_synchronously
                            context: dialogContext,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time == null) return;
                          setDialogState(() {
                            selectedDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final hours = double.tryParse(hoursController.text.replaceAll(',', '.')) ?? 0.0;
                    final persons = int.tryParse(personsController.text) ?? 0;
                    final helpers = List<String>.from(helperNames);

                    if (name.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bitte trage den Namen des Dienstes ein.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    if (isEntryMode) {
                      if (selectedDate == null || hours <= 0) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bitte Datum und Stunden ausfüllen.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                    } else {
                      if (hours <= 0 || persons <= 0) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bitte geschätzte Stunden und benötigte Personen ausfüllen.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                    }

                    try {
                      final body = <String, dynamic>{
                        'name': name,
                        'created_by': user.id,
                        'approved_by': isEntryMode && canApprove ? user.id : '',
                        'work_mode': isEntryMode ? 'eintragen' : 'ausschreiben',
                        'state': isEntryMode ? (canApprove ? 'approved' : 'open') : 'open',
                        'date': selectedDate?.toUtc().toIso8601String() ?? '',
                      };

                      if (isEntryMode) {
                        body['hours'] = hours;
                        body['persons_required'] = helpers.isEmpty ? 1 : helpers.length + 1;
                        body['hours_required'] = hours * (helpers.isEmpty ? 1 : helpers.length + 1);
                        body['helpers'] = helpers;
                      } else {
                        body['hours'] = hours;
                        body['persons_required'] = persons;
                        body['hours_required'] = hours;
                      }

                      await pb.collection('work').create(body: body);

                      if (canApprove) {
                        await _createNotification(
                          title: isEntryMode ? 'Dienst eingetragen' : 'Dienst ausgeschrieben',
                          message: '${user.getStringValue('forename')} ${user.getStringValue('surname')} hat einen Arbeitsdienst ${isEntryMode ? 'eingetragen' : 'ausgeschrieben'} und direkt genehmigt.',
                        );
                      }

                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEntryMode
                              ? 'Dienst eingetragen.'
                              : 'Dienst ausgeschrieben.'),
                        ),
                      );
                      await _loadWorkItems();
                    } catch (e) {
                      debugPrint('Fehler beim Erstellen: $e');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: Text(isEntryMode ? 'Eintragen' : 'Ausschreiben'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onAddButtonPressed() async {
    final isAppAdmin = user.getBoolValue('auth_admin_app');
    final permWork = isAppAdmin ? 2 : user.getIntValue('perm_board_work');
    final canChoose = isAppAdmin || permWork >= 2;

    if (!canChoose) {
      await _showCreateDialog(WorkCreateMode.eintragen);
      return;
    }

    final selection = await showDialog<WorkCreateMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dienst hinzufügen'),
        content: const Text('Möchtest du einen Dienst eintragen oder ausschreiben?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, WorkCreateMode.ausschreiben),
            child: const Text('Ausschreiben'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, WorkCreateMode.eintragen),
            child: const Text('Eintragen'),
          ),
        ],
      ),
    );
    if (selection != null) {
      await _showCreateDialog(selection);
    }
  }

  Future<void> _pickHelper(
    List<RecordModel> users,
    List<String> helperNames,
    void Function(void Function()) setDialogState,
  ) async {
    String searchQuery = '';
    final currentUserId = pb.authStore.record?.id;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredUsers = users.where((u) {
            final isMe = u.id == currentUserId;
            final isAlreadyAdded = helperNames.contains(
              '${u.getStringValue('forename')} ${u.getStringValue('surname')}'.trim(),
            );
            final isMember = u.getBoolValue('membership');
            final fullName =
                '${u.getStringValue('forename')} ${u.getStringValue('surname')}'.trim();
            final matchesSearch = fullName.toLowerCase().contains(searchQuery.toLowerCase());
            return isMember && !isMe && !isAlreadyAdded && matchesSearch;
          }).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Helfer suchen...',
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
                      final fullName =
                          '${userRecord.getStringValue('forename')} ${userRecord.getStringValue('surname')}'.trim();
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(fullName),
                        onTap: () {
                          setDialogState(() {
                            if (helperNames.length < 10) {
                              helperNames.add(fullName);
                            }
                          });
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

  Future<void> _createNotification({
    required String title,
    required String message,
  }) async {
    try {
      await pb.collection('notifications').create(body: {
        'title': title,
        'message': message,
        'category': 'info',
        'priority': 'normal',
        'scope': 'vorstand_work',
      });
    } catch (e) {
      debugPrint('Notification konnte nicht erstellt werden: $e');
    }
  }

  Widget _buildWorkCard(RecordModel item) {
    final date = DateTime.tryParse(item.getStringValue('date'))?.toLocal();
    final assumed = List<String>.from(item.getListValue('assumed_by').cast<String>());
    final currentCount = assumed.length;
    final maxCount = item.getIntValue('persons_required');
    final assigned = assumed.contains(user.id);
    final itemState = item.getStringValue('state');
    final isApproved = itemState == 'approved';
    final isAssumed = itemState == 'assumed';
    final createdBy = item.getStringValue('created_by');
    final approvedBy = item.getStringValue('approved_by');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.getStringValue('name'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isApproved ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isApproved
                        ? 'Abgeschlossen'
                        : isAssumed
                            ? 'Angenommen'
                            : 'Offen',
                    style: TextStyle(
                      color: isApproved
                          ? Colors.green.shade800
                          : isAssumed
                              ? Colors.blue.shade800
                              : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (date != null)
              Text(
                'Datum: ${DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(date)}',
              ),
            const SizedBox(height: 4),
            Text('Stunden pro Person: ${item.getStringValue('hours')}'),
            const SizedBox(height: 4),
            Text('Benötigte Personen: $currentCount / $maxCount'),
            const SizedBox(height: 4),
            Text('Benötigte Gesamtstunden: ${item.getStringValue('hours_required')}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: maxCount == 0 ? 0 : currentCount / maxCount,
              color: appFrontColor.value,
              backgroundColor: appFrontColor.value.withValues(alpha: 51),
            ),
            const SizedBox(height: 8),
            if (createdBy.isNotEmpty)
              Text('Erstellt von: ${createdBy == user.id ? 'Dir' : createdBy}'),
            if (approvedBy.isNotEmpty)
              Text('Genehmigt von: ${approvedBy == user.id ? 'Dir' : approvedBy}'),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isApproved) ...[
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: assigned ? Colors.red : appFrontColor.value,
                      ),
                      onPressed: itemState == 'approved' ? null : () => _toggleAssumption(item),
                      child: Text(assigned ? 'Abmelden' : 'Übernehmen'),
                    ),
                  ),
                ],
                if (!isApproved && canApprove) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _approveRequest(item),
                      child: const Text('Genehmigen'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () => _rejectRequest(item),
                      child: const Text('Ablehnen'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkSection(String title, List<RecordModel> items) {
    if (items.isEmpty) {
      return Center(
        child: Text('Keine $title vorhanden.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildWorkCard(items[index]),
    );
  }

  Widget _buildMyWorkSection() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deine Übersicht',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Deine Stunden: ${myCompletedWorkItems.fold<double>(0.0, (sum, item) {
                      final hours = double.tryParse(item.getStringValue('hours')) ?? 0.0;
                      return sum + hours;
                    }).toStringAsFixed(1)} Stunden'),
                const SizedBox(height: 8),
                Text('Angenommene Ausschreibungen: ${myAcceptedAnnouncements.length}'),
                const SizedBox(height: 4),
                Text('Angefragte Dienste (Prüfung ausstehend): ${myPendingRequests.length}'),
                const SizedBox(height: 4),
                Text('Abgeschlossene Dienste: ${myCompletedWorkItems.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (myAcceptedAnnouncements.isNotEmpty) ...[
          const Text('Angenommene Ausschreibungen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...myAcceptedAnnouncements.map((item) => _buildWorkCard(item)),
          const SizedBox(height: 16),
        ],
        if (myPendingRequests.isNotEmpty) ...[
          const Text('Angefragte Dienste', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...myPendingRequests.map((item) => _buildWorkCard(item)),
        ],
        if (myAcceptedAnnouncements.isEmpty && myPendingRequests.isEmpty) ...[
          const Center(child: Text('Du hast derzeit keine diensteigenen Einträge oder Anfragen.')),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: canApprove ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Arbeitsdienste'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Arbeitsdienst hinzufügen',
              onPressed: _onAddButtonPressed,
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'Ausschreibungen'),
              const Tab(text: 'Meine Dienste'),
              if (canApprove) const Tab(text: 'Anfragen'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildWorkSection('Ausschreibungen', workItems),
                  _buildMyWorkSection(),
                  if (canApprove) _buildWorkSection('Anfragen', approvalRequests),
                ],
              ),
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final messageController = TextEditingController();
  bool isCopied = false;

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _copyAdminEmail() async {
    if (adminFeedbackEmail.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: adminFeedbackEmail));
    if (!mounted) return;
    setState(() => isCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin-E-Mail in die Zwischenablage kopiert.')),
    );
  }

  Future<void> _submitFeedback() async {
    if (adminFeedbackEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Admin-Mail hinterlegt. Bitte den Vorstand direkt kontaktieren.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst eine Nachricht schreiben.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = pb.authStore.record as RecordModel?;
    final fromEmail = user?.getStringValue('email') ?? '';
    final fromName = user != null
        ? '${user.getStringValue('forename')} ${user.getStringValue('surname')}'
        : 'App-Benutzer';

    final subject = 'Verbesserungsvorschlag von $fromName';
    final body = '${messageController.text}\n\nVon: $fromName\nE-Mail: $fromEmail';

    final settingsSvc = AppSettingsService(pb);
    final emailSvc = EmailService(settingsSvc);
    final sent = await emailSvc.sendFeedback(
      to: adminFeedbackEmail,
      subject: subject,
      body: body,
      fromEmail: fromEmail.isNotEmpty ? fromEmail : null,
      fromName: fromName,
    );

    if (sent) {
      if (!mounted) return;
      messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback wurde per E-Mail an den Vorstand gesendet.'),
        ),
      );
    } else {
      // fallback: copy admin email to clipboard and instruct user
      await Clipboard.setData(ClipboardData(text: adminFeedbackEmail));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Feedback vorbereitet. SMTP nicht konfiguriert oder Versand fehlgeschlagen. Bitte sende deine Nachricht an $adminFeedbackEmail.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminEmailText = adminFeedbackEmail.isEmpty
        ? 'Noch keine Admin-E-Mail eingetragen.'
        : adminFeedbackEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verbesserungsvorschläge'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Verbesserungsvorschläge',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Empfänger',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(adminEmailText),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('E-Mail kopieren'),
                    onPressed: adminFeedbackEmail.isEmpty ? null : _copyAdminEmail,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: messageController,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Dein Vorschlag',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appFrontColor.value,
            ),
            onPressed: _submitFeedback,
            child: const Text('Feedback vorbereiten'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hinweis: Zur Zeit wird die Mailadresse in die Zwischenablage kopiert. '
            'Öffne dein E-Mail-Programm und sende deine Nachricht an den Vorstand.',
          ),
        ],
      ),
    );
  }
}

class MembershipInfoPage extends StatefulWidget {
  const MembershipInfoPage({super.key});

  @override
  State<MembershipInfoPage> createState() => _MembershipInfoPageState();
}

class _MembershipInfoPageState extends State<MembershipInfoPage> {
  bool _loading = false;
  late RecordModel user;

  @override
  void initState() {
    super.initState();
    user = pb.authStore.record as RecordModel;
  }

  Future<void> _toggleMembershipRequest() async {
    setState(() => _loading = true);
    final hasRequested = user.getBoolValue('membership_request');
    try {
      await pb.collection('users').update(
        user.id,
        body: {'membership_request': !hasRequested},
      );
      final refreshed = await pb.collection('users').getOne(user.id);
      user = refreshed;

      if (!hasRequested) {
        await NotificationWorkflowService.createMembershipRequest(
          requester: user,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasRequested
              ? 'Mitgliedschaftsanfrage zurückgezogen.'
              : 'Mitgliedschaftsanfrage gestellt.'),
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMember = user.getBoolValue('membership');
    final hasRequested = user.getBoolValue('membership_request');
    final status = isMember
        ? 'Du bist Mitglied'
        : (hasRequested ? 'Anfrage ausstehend' : 'Kein Mitglied');
    final statusColor = isMember
        ? Colors.green
        : (hasRequested ? Colors.orange : Colors.grey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitgliedschaftsinfo / Anfrage'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isMember)
                    const Text(
                      'Als Mitglied kannst du alle Vereinsangebote nutzen. Deine Mitgliedschaft ist aktiv.',
                    )
                  else if (hasRequested)
                    const Text(
                      'Deine Anfrage wurde gestellt. Der Vorstand prüft sie und meldet sich zurück.',
                    )
                  else
                    const Text(
                      'Du bist aktuell kein Mitglied. Hier kannst du eine Mitgliedschaftsanfrage stellen.',
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMember
                            ? Colors.grey
                            : (hasRequested ? Colors.red : appFrontColor.value),
                      ),
                      onPressed: isMember || _loading ? null : _toggleMembershipRequest,
                      child: Text(
                        isMember
                            ? 'Bereits Mitglied'
                            : (hasRequested ? 'Anfrage zurückziehen' : 'Mitgliedschaft anfragen'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mitgliedschaftsinfo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Der Vorstand entscheidet über Mitgliedsanträge. Bei Fragen kontaktiere bitte den Vorstand oder verwende das Feedback-Formular.',
          ),
        ],
      ),
    );
  }
}
