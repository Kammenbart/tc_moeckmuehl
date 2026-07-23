import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart';

class TrainerCustomersTab extends StatefulWidget {
  const TrainerCustomersTab({super.key});

  @override
  State<TrainerCustomersTab> createState() => _TrainerCustomersTabState();
}

class _TrainerCustomersTabState extends State<TrainerCustomersTab> with TickerProviderStateMixin {
  List<RecordModel> myCustomers = [];
  List<RecordModel> filteredCustomers = [];
  List<RecordModel> allCustomers = [];
  bool isLoading = true;
  String searchQuery = "";
  final searchController = TextEditingController();
  TabController? _tabController;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController?.addListener(() {
      setState(() {});
    });
    _loadCustomers();
    _loadAllCustomers();
  }

  Future<void> _loadCustomers() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final trainer = pb.authStore.record as RecordModel;

      final relationResult = await _loadCustomersFromRelationSafe(trainer.id);
      final result = relationResult.isNotEmpty
          ? relationResult
          : await _loadCustomersSafe(trainer.id);
      
      debugPrint('✓ ${result.length} Customers geladen');

      if (mounted) {
        setState(() {
          myCustomers = result;
          filteredCustomers = result;
        });
      }
    } catch (e) {
      debugPrint('✗ Fehler beim Laden: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<List<RecordModel>> _loadCustomersSafe(String trainerId) async {
    final attempts = <String?>[
      'trainer ~ "$trainerId"',
      null,
    ];

    for (final filter in attempts) {
      try {
        final records = await pb.collection('users').getFullList(
          filter: filter,
          sort: 'surname,forename',
        );

        if (filter != null) {
          return records;
        }

        return records.where((record) => _hasTrainerAssigned(record, trainerId)).toList();
      } on ClientException catch (e) {
        debugPrint('users Versuch fehlgeschlagen (filter: $filter): $e');
        continue;
      } catch (e) {
        debugPrint('users unerwarteter Fehler (filter: $filter): $e');
        continue;
      }
    }

    return const [];
  }

  Future<List<RecordModel>> _loadCustomersFromRelationSafe(String trainerId) async {
    List<RecordModel> links = [];
    try {
      links = await pb.collection('trainer_customers').getFullList(
            filter: 'trainer = "$trainerId"',
            sort: '-created',
            expand: 'customer,user,member',
          );
    } catch (e) {
      debugPrint('trainer_customers nicht nutzbar: $e');
      return const [];
    }

    if (links.isEmpty) return const [];

    final byId = <String, RecordModel>{};
    final ids = <String>{};

    for (final link in links) {
      final json = link.toJson();
      final rawCandidates = [json['customer'], json['user'], json['member']];
      for (final raw in rawCandidates) {
        ids.addAll(_extractIds(raw));
      }

      final expandedCandidates = [
        link.get<List<RecordModel>>('expand.customer'),
        link.get<List<RecordModel>>('expand.user'),
        link.get<List<RecordModel>>('expand.member'),
      ];
      for (final expandedList in expandedCandidates) {
        for (final record in expandedList) {
          byId[record.id] = record;
        }
      }
    }

    if (byId.isNotEmpty) {
      final expanded = byId.values.toList();
      expanded.sort(
        (a, b) => ('${a.getStringValue('surname')} ${a.getStringValue('forename')}')
            .toLowerCase()
            .compareTo(
              ('${b.getStringValue('surname')} ${b.getStringValue('forename')}').toLowerCase(),
            ),
      );
      return expanded;
    }

    if (ids.isEmpty) return const [];

    try {
      final users = await pb.collection('users').getFullList(sort: 'surname,forename');
      return users.where((u) => ids.contains(u.id)).toList();
    } catch (e) {
      debugPrint('users lookup via trainer_customers ids fehlgeschlagen: $e');
      return const [];
    }
  }

  List<String> _extractIds(dynamic raw) {
    final values = <String>[];
    if (raw is String) {
      final value = raw.trim();
      if (value.isNotEmpty) values.add(value);
      return values;
    }
    if (raw is List) {
      for (final entry in raw) {
        values.addAll(_extractIds(entry));
      }
      return values;
    }
    if (raw is Map) {
      final value = (raw['id'] ?? raw['user'] ?? raw['customer'] ?? raw['member'] ?? '').toString().trim();
      if (value.isNotEmpty) values.add(value);
    }
    return values;
  }

  List<String> _extractTrainerIds(RecordModel user) {
    final ids = <String>[];
    final raw = user.toJson()['trainer'];

    if (raw is String) {
      final value = raw.trim();
      if (value.isNotEmpty) ids.add(value);
    } else if (raw is List) {
      for (final item in raw) {
        if (item is String) {
          final value = item.trim();
          if (value.isNotEmpty) ids.add(value);
        } else if (item is Map) {
          final value = (item['id'] ?? item['trainer'] ?? '').toString().trim();
          if (value.isNotEmpty) ids.add(value);
        }
      }
    } else if (raw is Map) {
      final value = (raw['id'] ?? raw['trainer'] ?? '').toString().trim();
      if (value.isNotEmpty) ids.add(value);
    }

    return ids;
  }

  bool _hasTrainerAssigned(RecordModel user, String trainerId) {
    return _extractTrainerIds(user).contains(trainerId);
  }

  bool _hasAnyTrainer(RecordModel user) {
    return _extractTrainerIds(user).isNotEmpty;
  }

  void _filterCustomers() {
    setState(() {
      filteredCustomers = myCustomers.where((user) {
        final name =
            "${user.getStringValue('forename')} ${user.getStringValue('surname')}"
                .toLowerCase();
        final email = user.getStringValue('email').toLowerCase();
        final search = searchQuery.toLowerCase();

        return name.contains(search) || email.contains(search);
      }).toList();
    });
  }

  Future<void> _removeCustomer(RecordModel customer) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Kunde entfernen?"),
            content: Text(
              "Möchtest du ${customer.getStringValue('forename')} ${customer.getStringValue('surname')} wirklich entfernen?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Entfernen"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      // Entferne die Trainer-Zuordnung
      await pb.collection('users').update(
        customer.id,
        body: {'trainer': null},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kunde entfernt."),
            backgroundColor: Colors.red,
          ),
        );
        _loadCustomers();
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
    if (_tabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kundenstamm'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Meine Kunden'),
            Tab(text: 'Alle Kunden'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCustomersTab(),
                _buildAllCustomersTab(),
              ],
            ),
      floatingActionButton: _tabController?.index == 0
          ? FloatingActionButton(
              backgroundColor: appFrontColor.value,
              onPressed: _isAssigning ? null : () => _selectUsersToAssignAsTrainer(),
              child: _isAssigning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildCustomersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: "Kunden durchsuchen...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() => searchQuery = value);
              _filterCustomers();
            },
          ),
        ),
        Expanded(
          child: filteredCustomers.isEmpty
              ? Center(
                  child: Text(
                    searchQuery.isEmpty
                        ? "Keine Kunden vorhanden."
                        : "Keine Kunden gefunden.",
                  ),
                )
              : ListView.builder(
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            customer.getStringValue('forename').isNotEmpty
                                ? customer.getStringValue('forename')[0]
                                : 'U',
                          ),
                        ),
                        title: Text(
                          "${customer.getStringValue('forename')} ${customer.getStringValue('surname')}",
                        ),
                        subtitle: Text(
                          customer.getStringValue('email'),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeCustomer(customer),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAllCustomersTab() {
    return allCustomers.isEmpty
        ? const Center(child: Text('Keine Kunden vorhanden.'))
        : ListView.builder(
            itemCount: allCustomers.length,
            itemBuilder: (context, index) {
              final user = allCustomers[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      user.getStringValue('forename').isNotEmpty
                          ? user.getStringValue('forename')[0]
                          : 'U',
                    ),
                  ),
                  title: Text(
                    "${user.getStringValue('forename')} ${user.getStringValue('surname')}",
                  ),
                  subtitle: Text(
                    user.getStringValue('email'),
                  ),
                ),
              );
            },
          );
  }

  Future<void> _selectUsersToAssignAsTrainer() async {
    final trainer = pb.authStore.record as RecordModel;
    final alreadyAssignedIds = myCustomers.map((user) => user.id).toSet();
    List<RecordModel> allUsers = [];
    try {
      allUsers = await pb.collection('users').getFullList(
        sort: 'surname,forename',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Benutzerliste konnte nicht geladen werden: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final availableUsers = allUsers.where((user) {
      if (user.id == trainer.id) return false;
      if (alreadyAssignedIds.contains(user.id)) return false;
      if (_hasTrainerAssigned(user, trainer.id)) return false;
      return true;
    }).toList();

    final Set<String> selectedUserIds = {};
    var searchQuery = '';

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Benutzer zuordnen'),
            content: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    '${selectedUserIds.length} ausgewählt',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Benutzer suchen...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setDialogState(() => searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final filteredUsers = availableUsers.where((user) {
                          if (searchQuery.trim().isEmpty) return true;
                          final fullName =
                              '${user.getStringValue('forename')} ${user.getStringValue('surname')}'.toLowerCase();
                          final email = user.getStringValue('email').toLowerCase();
                          final query = searchQuery.toLowerCase();
                          return fullName.contains(query) || email.contains(query);
                        }).toList();

                        if (filteredUsers.isEmpty) {
                          return const Center(
                            child: Text('Keine passenden Benutzer verfügbar.'),
                          );
                        }

                        return ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final userId = user.id;
                            final isSelected = selectedUserIds.contains(userId);

                            return CheckboxListTile(
                              value: isSelected,
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -3),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selectedUserIds.add(userId);
                                  } else {
                                    selectedUserIds.remove(userId);
                                  }
                                });
                              },
                              title: Text(
                                '${user.getStringValue('forename')} ${user.getStringValue('surname')}',
                              ),
                              subtitle: Text(user.getStringValue('email')),
                            );
                          },
                        );
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
                onPressed: selectedUserIds.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _assignUsersAsCustomers(selectedUserIds);
                      },
                child: const Text('Zuordnen'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assignUsersAsCustomers(Set<String> userIds) async {
    if (!mounted) return;
    setState(() => _isAssigning = true);

    final trainer = pb.authStore.record as RecordModel;
    var successCount = 0;
    var failCount = 0;
    String? firstError;

    for (final userId in userIds) {
      try {
        try {
          await pb.collection('trainer_customers').create(
            body: {'trainer': trainer.id, 'customer': userId},
          );
        } catch (_) {
          await pb.collection('users').update(
            userId,
            body: {'trainer': trainer.id},
          );
        }
        successCount++;
      } catch (e) {
        failCount++;
        firstError ??= e.toString();
      }
    }

    await _loadCustomers();
    await _loadAllCustomers();

    if (!mounted) return;
    setState(() => _isAssigning = false);

    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount Benutzer zugeordnet.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$successCount zugeordnet, $failCount fehlgeschlagen.${firstError == null ? '' : ' ($firstError)'}',
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadAllCustomers() async {
    try {
      final result = await pb.collection('users').getFullList(
        sort: 'surname,forename',
      );
      var withTrainer = result.where(_hasAnyTrainer).toList();

      if (withTrainer.isEmpty) {
        final links = await pb.collection('trainer_customers').getFullList(
              sort: '-created',
              expand: 'customer,user,member',
            );
        final byId = <String, RecordModel>{};
        for (final link in links) {
          final expandedCandidates = [
            link.get<List<RecordModel>>('expand.customer'),
            link.get<List<RecordModel>>('expand.user'),
            link.get<List<RecordModel>>('expand.member'),
          ];
          for (final expandedList in expandedCandidates) {
            for (final record in expandedList) {
              byId[record.id] = record;
            }
          }
        }
        withTrainer = byId.values.toList();
      }

      if (mounted) {
        setState(() => allCustomers = withTrainer);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden aller Kunden: $e');
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    searchController.dispose();
    super.dispose();
  }
}
