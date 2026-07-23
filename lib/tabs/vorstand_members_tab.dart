import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../main.dart';
import '../services/member_csv_service.dart';

/// (Optional) alter Dialog – wird aktuell nicht benutzt, kann später gelöscht werden.
Future<void> showMemberEditDialog(
  BuildContext context, {
  RecordModel? member,
  required int permission,
}) async {
  final isEdit = member != null;
  final forenameController = TextEditingController(
    text: isEdit ? member.getStringValue('forename') : '',
  );
  final surnameController = TextEditingController(
    text: isEdit ? member.getStringValue('surname') : '',
  );
  final emailController = TextEditingController(
    text: isEdit ? member.getStringValue('email') : '',
  );
  final clubIdController = TextEditingController(
    text: isEdit ? member.getStringValue('club_id') : '',
  );
  final ibanController = TextEditingController(
    text: isEdit ? member.getStringValue('iban') : '',
  );
  final bicController = TextEditingController(
    text: isEdit ? member.getStringValue('bic') : '',
  );
  final bankNameController = TextEditingController(
    text: isEdit ? member.getStringValue('bank_name') : '',
  );
  final bankOwnerController = TextEditingController(
    text: isEdit ? member.getStringValue('bank_owner') : '',
  );
  final phoneController = TextEditingController(
    text: isEdit ? member.getStringValue('phone') : '',
  );
  final mobileController = TextEditingController(
    text: isEdit ? member.getStringValue('mobile') : '',
  );
  final passwordController = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(isEdit ? "Mitglied bearbeiten" : "Mitglied hinzufügen"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: forenameController,
                decoration: const InputDecoration(labelText: "Vorname"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: surnameController,
                decoration: const InputDecoration(labelText: "Nachname"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "E-Mail"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: isEdit ? "Neues Passwort (optional)" : "Passwort",
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: clubIdController,
                decoration: const InputDecoration(labelText: "Club-ID"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Telefon"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: mobileController,
                decoration: const InputDecoration(labelText: "Mobil"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ibanController,
                decoration: const InputDecoration(labelText: "IBAN"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bicController,
                decoration: const InputDecoration(labelText: "BIC"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bankNameController,
                decoration: const InputDecoration(labelText: "Bankname"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bankOwnerController,
                decoration: const InputDecoration(labelText: "Kontoinhaber"),
              ),
              const SizedBox(height: 16),
              if (permission < 2)
                const Text(
                  "Du hast keine Berechtigung zum Bearbeiten/Hinzufügen.",
                  style: TextStyle(color: Colors.red),
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
            onPressed: permission < 2
                ? null
                : () async {
                    final forename = forenameController.text.trim();
                    final surname = surnameController.text.trim();
                    final email = emailController.text.trim();
                    final password = passwordController.text.trim();

                    if (surname.isEmpty || email.isEmpty || forename.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Vorname, Nachname und E-Mail dürfen nicht leer sein.",
                          ),
                        ),
                      );
                      return;
                    }

                    if (!isEdit && password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Für neue Mitglieder ist ein Passwort nötig.",
                          ),
                        ),
                      );
                      return;
                    }

                    final body = {
                      "surname": surname,
                      "email": email,
                      "club_id": clubIdController.text.trim(),
                      "phone": phoneController.text.trim(),
                      "mobile": mobileController.text.trim(),
                      "iban": ibanController.text.trim(),
                      "bic": bicController.text.trim(),
                      "bank_name": bankNameController.text.trim(),
                      "bank_owner": bankOwnerController.text.trim(),
                    };

                    try {
                      if (isEdit) {
                        if (password.isNotEmpty) {
                          body["password"] = password;
                          body["passwordConfirm"] = password;
                        }
                        await pb
                            .collection('users')
                            .update(member.id, body: body);
                      } else {
                        body["password"] = password;
                        body["passwordConfirm"] = password;
                        await pb.collection('users').create(body: body);
                      }

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEdit
                                  ? "Mitglied aktualisiert."
                                  : "Mitglied angelegt.",
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint("Fehler beim Speichern: $e");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Speichern fehlgeschlagen. Bitte prüfen.",
                            ),
                          ),
                        );
                      }
                    }
                  },
            child: Text(isEdit ? "Speichern" : "Anlegen"),
          ),
        ],
      );
    },
  );
}

/// Haupt-Tab: Mitgliederliste
class VorstandMembersTab extends StatefulWidget {
  final int permission; // 1: sehen, 2: +hinzufügen, 3: +löschen, 4: +rechte
  final ValueChanged<int>? onPendingRequestsChanged;
  final ValueChanged<List<Widget>>? onAppBarActionsChanged;

  const VorstandMembersTab({
    super.key,
    required this.permission,
    this.onPendingRequestsChanged,
    this.onAppBarActionsChanged,
  });

  @override
  State<VorstandMembersTab> createState() => _VorstandMembersTabState();
}

class _VorstandMembersTabState extends State<VorstandMembersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RecordModel> members = [];
  List<RecordModel> filteredMembers = [];
  List<RecordModel> appUsers = [];
  List<RecordModel> filteredAppUsers = [];
  List<RecordModel> membershipRequests = [];
  int pendingRequestCount = 0;
  bool isLoading = true;
  String searchQuery = "";
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAppBarActions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final membersRes = await pb
          .collection('users')
          .getFullList(filter: 'membership = true', sort: 'surname');
      final appUsersRes = await pb
          .collection('users')
          .getFullList(filter: 'membership = false', sort: 'surname');
      final requestsRes = await pb
          .collection('users')
          .getFullList(
            filter: 'membership_request = true && membership = false',
            sort: '-created',
          );

      debugPrint("Mitglieder geladen: ${membersRes.length}");
      debugPrint("App-Nutzer geladen: ${appUsersRes.length}");

      if (mounted) {
        setState(() {
          members = membersRes;
          filteredMembers = membersRes;
          appUsers = appUsersRes;
          filteredAppUsers = appUsersRes;
          membershipRequests = requestsRes;
          pendingRequestCount = requestsRes.length;
        });
        widget.onPendingRequestsChanged?.call(requestsRes.length);
        _refreshAppBarActions();
      }
    } catch (e) {
      debugPrint("Fehler beim Laden: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Fehler beim Laden der Mitglieder: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _filterMembers(String query) {
    setState(() {
      searchQuery = query;
      filteredMembers = members.where((m) {
        final surname = m.getStringValue('surname').toLowerCase();
        final email = m.getStringValue('email').toLowerCase();
        return surname.contains(query.toLowerCase()) ||
            email.contains(query.toLowerCase());
      }).toList();
      filteredAppUsers = appUsers.where((m) {
        final surname = m.getStringValue('surname').toLowerCase();
        final email = m.getStringValue('email').toLowerCase();
        return surname.contains(query.toLowerCase()) ||
            email.contains(query.toLowerCase());
      }).toList();
    });
  }

  Widget _buildUserListView(
    List<RecordModel> users,
    bool canWrite,
    bool canDelete,
    bool isAppAdmin,
    int perm,
  ) {
    if (users.isNotEmpty) {
      return ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final m = users[index];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(
              "${m.getStringValue('forename')} ${m.getStringValue('surname')}",
            ),
            subtitle: Text(m.getStringValue('email')),
            onTap: canWrite
                ? () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VorstandMembersEditTab(member: m),
                      ),
                    );
                    _loadData();
                  }
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (perm >= 4 || isAppAdmin)
                  IconButton(
                    icon: const Icon(Icons.security, color: Colors.blue),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VorstandMembersPermTab(member: m),
                        ),
                      );
                      _loadData();
                    },
                  ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _handleDelete(m),
                  ),
              ],
            ),
          );
        },
      );
    }

    return Center(
      child: Text(
        searchQuery.isEmpty
            ? 'Keine ${_tabController.index == 0 ? 'Mitglieder' : 'App-Nutzer'} gefunden.'
            : 'Keine ${_tabController.index == 0 ? 'Mitglieder' : 'App-Nutzer'} zur Suche gefunden.',
      ),
    );
  }

  void _refreshAppBarActions() {
    final record = pb.authStore.record as RecordModel;
    final isAppAdmin = record.getBoolValue('auth_admin_app');
    final canWrite = widget.permission >= 2 || isAppAdmin;

    final actions = <Widget>[
      IconButton(
        onPressed: _openMembershipRequestsPage,
        tooltip: pendingRequestCount > 0
            ? 'Offene Bewerbungen ($pendingRequestCount)'
            : 'Bewerbungen',
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.person_add),
            if (pendingRequestCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    pendingRequestCount > 9 ? '9+' : '$pendingRequestCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (canWrite)
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'export') {
              MemberCsvImportExport.exportMembersToCSV(
                context,
                _tabController.index == 0
                    ? MemberCsvExportType.members
                    : MemberCsvExportType.appUsers,
              );
            } else if (value == 'import') {
              MemberCsvImportExport.importMembersFromCSV(
                context,
              ).then((_) => _loadData());
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.upload, size: 20),
                  SizedBox(width: 8),
                  Text('CSV importieren'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 8),
                  Text('CSV exportieren'),
                ],
              ),
            ),
          ],
        ),
    ];
    widget.onAppBarActionsChanged?.call(actions);
  }

  Future<void> _approveMembershipRequest(RecordModel targetUser) async {
    final confirm = await _showConfirmDialog(
      "Mitgliedschaft genehmigen?",
      "Möchtest du ${targetUser.getStringValue('forename')} ${targetUser.getStringValue('surname')} als Mitglied akzeptieren?",
    );
    if (!confirm) return;

    try {
      await pb
          .collection('users')
          .update(
            targetUser.id,
            body: {'membership': true, 'membership_request': false},
          );
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mitgliedschaft genehmigt.")),
        );
      }
    } catch (e) {
      debugPrint("Fehler beim Genehmigen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectMembershipRequest(RecordModel targetUser) async {
    final confirm = await _showConfirmDialog(
      "Mitgliedschaftsanfrage ablehnen?",
      "Möchtest du die Anfrage von ${targetUser.getStringValue('forename')} ${targetUser.getStringValue('surname')} ablehnen?",
    );
    if (!confirm) return;

    try {
      await pb
          .collection('users')
          .update(
            targetUser.id,
            body: {'membership': false, 'membership_request': false},
          );
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Anfrage abgelehnt.")));
      }
    } catch (e) {
      debugPrint("Fehler beim Ablehnen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDelete(RecordModel targetUser) async {
    if (widget.permission >= 3) {
      final confirm = await _showConfirmDialog(
        "Mitglied löschen",
        "Möchtest du ${targetUser.getStringValue('surname')} wirklich unwiderruflich löschen?",
      );
      if (confirm) {
        await pb.collection('users').delete(targetUser.id);
        _loadData();
      }
    } else {
      final confirm = await _showConfirmDialog(
        "Löschung anfragen",
        "Du hast keine Löschrechte. Soll eine Anfrage an den Hauptvorstand gesendet werden?",
      );
      if (confirm) {
        await pb
            .collection('member_delete_requests')
            .create(
              body: {
                "requested_by": pb.authStore.model!.id,
                "target_user": targetUser.id,
                "status": "pending",
              },
            );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Anfrage gesendet.")));
        }
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String text) async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Bestätigen"),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openMembershipRequestsPage() {
    final record = pb.authStore.record as RecordModel;
    final isAppAdmin = record.getBoolValue('auth_admin_app');
    final canWrite = widget.permission >= 2 || isAppAdmin;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MembershipRequestsPage(
          requests: membershipRequests,
          canApprove: canWrite,
          canReject: canWrite,
          onApprove: _approveMembershipRequest,
          onReject: _rejectMembershipRequest,
          onReload: _loadData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Rechte für diesen Tab OBEN definieren, vor isLoading
    final record = pb.authStore.record as RecordModel;
    final isAppAdmin = record.getBoolValue('auth_admin_app');
    final perm = widget.permission;

    final canRead = perm >= 1 || isAppAdmin;
    final canWrite = perm >= 2 || isAppAdmin;
    final canDelete = perm >= 3 || isAppAdmin;

    // 2. Optional: wenn jemand gar kein Leserecht hat, direkt blocken
    if (!canRead) {
      return const Scaffold(
        body: Center(child: Text("Keine Berechtigung, Mitglieder zu sehen.")),
      );
    }

    // 3. Loading-Zustand
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 4. Normale Ansicht
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: appFrontColor.value,
              labelColor: appFrontColor.value,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Mitglieder'),
                Tab(text: 'App-Nutzer'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              onChanged: _filterMembers,
              decoration: InputDecoration(
                hintText: "Suchen...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (pendingRequestCount > 0 && _tabController.index == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.orange),
                  title: Text('$pendingRequestCount offene Bewerbungen'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _openMembershipRequestsPage,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserListView(
                  filteredMembers,
                  canWrite,
                  canDelete,
                  isAppAdmin,
                  perm,
                ),
                _buildUserListView(
                  filteredAppUsers,
                  canWrite,
                  canDelete,
                  isAppAdmin,
                  perm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const VorstandMembersCreateTab(),
                  ),
                );
                _loadData();
              },
              backgroundColor: appFrontColor.value,
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }
}

class _MembershipRequestsPage extends StatelessWidget {
  final List<RecordModel> requests;
  final bool canApprove;
  final bool canReject;
  final Future<void> Function(RecordModel) onApprove;
  final Future<void> Function(RecordModel) onReject;
  final Future<void> Function() onReload;

  const _MembershipRequestsPage({
    super.key,
    required this.requests,
    required this.canApprove,
    required this.canReject,
    required this.onApprove,
    required this.onReject,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bewerbungen')),
      body: requests.isEmpty
          ? const Center(child: Text('Keine offenen Bewerbungen.'))
          : RefreshIndicator(
              onRefresh: onReload,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final created = DateTime.parse(
                    req.getStringValue('created'),
                  ).toLocal();
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.person_add,
                        color: Colors.orange,
                      ),
                      title: Text(
                        '${req.getStringValue('forename')} ${req.getStringValue('surname')}',
                      ),
                      subtitle: Text(
                        'Angefordert: ${DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(created)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canReject)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Ablehnen',
                              onPressed: () async {
                                await onReject(req);
                                await onReload();
                              },
                            ),
                          if (canApprove)
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              tooltip: 'Genehmigen',
                              onPressed: () async {
                                await onApprove(req);
                                await onReload();
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Rechte-Screen für ein Mitglied
class VorstandMembersPermTab extends StatefulWidget {
  final RecordModel member;

  const VorstandMembersPermTab({super.key, required this.member});

  @override
  State<VorstandMembersPermTab> createState() => _VorstandMembersPermTabState();
}

class _VorstandMembersPermTabState extends State<VorstandMembersPermTab> {
  late bool authVorstand;
  late bool authTrainer;
  late bool authAdmin;

  late int permMember;
  late int permKasse;
  late int permBooking;
  late int permNews;
  late int permWork;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    authVorstand = m.getBoolValue('auth_vorstand');
    authTrainer = m.getBoolValue('auth_trainer');
    authAdmin = m.getBoolValue('auth_admin');

    permMember = m.getIntValue('perm_board_member');
    permKasse = m.getIntValue('perm_board_cash');
    permBooking = m.getIntValue('perm_board_booking');
    permNews = m.getIntValue('perm_board_news');
    permWork = m.getIntValue('perm_board_work');
  }

  Future<void> _save() async {
    final body = {
      "auth_vorstand": authVorstand,
      "auth_trainer": authTrainer,
      "auth_admin": authAdmin,
      "perm_board_member": permMember,
      "perm_board_cash": permKasse,
      "perm_board_booking": permBooking,
      "perm_board_news": permNews,
      "perm_board_work": permWork,
    };

    try {
      await pb.collection('users').update(widget.member.id, body: body);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Rechte gespeichert.")));
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Fehler beim Speichern der Rechte: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speichern der Rechte fehlgeschlagen.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final surname = widget.member.getStringValue('surname');

    return Scaffold(
      appBar: AppBar(
        title: Text('Rechte: $surname'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rollen", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text("Vorstand"),
              value: authVorstand,
              onChanged: (v) => setState(() => authVorstand = v),
            ),
            SwitchListTile(
              title: const Text("Trainer"),
              value: authTrainer,
              onChanged: (v) => setState(() => authTrainer = v),
            ),
            SwitchListTile(
              title: const Text("Admin"),
              value: authAdmin,
              onChanged: (v) => setState(() => authAdmin = v),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              "Vorstandsrechte",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("Mitgliederverwaltung"),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: permMember,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Kein Zugriff")),
                DropdownMenuItem(value: 1, child: Text("Nur ansehen")),
                DropdownMenuItem(
                  value: 2,
                  child: Text("Ansehen, hinzufügen & bearbeiten"),
                ),
                DropdownMenuItem(value: 3, child: Text("Wie oben + löschen")),
                DropdownMenuItem(
                  value: 4,
                  child: Text("Wie oben + Rechte vergeben"),
                ),
              ],
              onChanged: (v) => setState(() => permMember = v ?? 0),
            ),
            const SizedBox(height: 16),
            const Text("Kasse"),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: permKasse,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Kein Zugriff")),
                DropdownMenuItem(value: 1, child: Text("Nur einsehen")),
                DropdownMenuItem(
                  value: 2,
                  child: Text("Einsehen & Buchungen erfassen"),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text("Vollzugriff (inkl. Storno/Export)"),
                ),
              ],
              onChanged: (v) => setState(() => permKasse = v ?? 0),
            ),
            const SizedBox(height: 16),
            const Text("Platzbuchungen"),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: permBooking,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Kein Zugriff")),
                DropdownMenuItem(value: 1, child: Text("Nur ansehen")),
                DropdownMenuItem(
                  value: 2,
                  child: Text("Eigene Buchungen verwalten"),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text("Vollzugriff (alle Buchungen)"),
                ),
              ],
              onChanged: (v) => setState(() => permBooking = v ?? 0),
            ),
            const SizedBox(height: 16),
            const Text("Arbeitsdienste"),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: permWork,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Kein Zugriff")),
                DropdownMenuItem(value: 1, child: Text("Genehmigen")),
                DropdownMenuItem(value: 2, child: Text("Erstellen + Genehmigen")),
              ],
              onChanged: (v) => setState(() => permWork = v ?? 0),
            ),
            const SizedBox(height: 16),
            const Text("Aktuelles (News)"),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: permNews,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Kein Zugriff")),
                DropdownMenuItem(
                  value: 1,
                  child: Text("Nur eigene News erstellen & bearbeiten"),
                ),
                DropdownMenuItem(
                  value: 2,
                  child: Text("Alle News bearbeiten & löschen"),
                ),
              ],
              onChanged: (v) => setState(() => permNews = v ?? 0),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mitglied anlegen
class VorstandMembersCreateTab extends StatefulWidget {
  const VorstandMembersCreateTab({super.key});

  @override
  State<VorstandMembersCreateTab> createState() =>
      _VorstandMembersCreateTabState();
}

class _VorstandMembersCreateTabState extends State<VorstandMembersCreateTab> {
  final _formKey = GlobalKey<FormState>();

  final forenameController = TextEditingController();
  final surnameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final clubIdController = TextEditingController();
  final phoneController = TextEditingController();
  final mobileController = TextEditingController();
  final ibanController = TextEditingController();
  final bicController = TextEditingController();
  final bankNameController = TextEditingController();
  final bankOwnerController = TextEditingController();

  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final body = {
      "forename": forenameController.text.trim(),
      "surname": surnameController.text.trim(),
      "email": emailController.text.trim(),
      "password": passwordController.text.trim(),
      "passwordConfirm": passwordController.text.trim(),
      "club_id": clubIdController.text.trim(),
      "phone": phoneController.text.trim(),
      "mobile": mobileController.text.trim(),
      "iban": ibanController.text.trim(),
      "bic": bicController.text.trim(),
      "bank_name": bankNameController.text.trim(),
      "bank_owner": bankOwnerController.text.trim(),
    };

    try {
      await pb.collection('users').create(body: body);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Mitglied angelegt.")));
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Fehler beim Anlegen: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speichern fehlgeschlagen.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mitglied hinzufügen"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: forenameController,
                decoration: const InputDecoration(labelText: "Vorname"),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Vorname erforderlich"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: surnameController,
                decoration: const InputDecoration(labelText: "Nachname"),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Nachname erforderlich"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "E-Mail"),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "E-Mail erforderlich"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: "Passwort"),
                obscureText: true,
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Passwort erforderlich"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: clubIdController,
                decoration: const InputDecoration(labelText: "Club-ID"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Telefon"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: mobileController,
                decoration: const InputDecoration(labelText: "Mobil"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: ibanController,
                decoration: const InputDecoration(labelText: "IBAN"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: bicController,
                decoration: const InputDecoration(labelText: "BIC"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: bankNameController,
                decoration: const InputDecoration(labelText: "Bankname"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: bankOwnerController,
                decoration: const InputDecoration(labelText: "Kontoinhaber"),
              ),
              const SizedBox(height: 16),
              if (_saving) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mitglied bearbeiten
class VorstandMembersEditTab extends StatefulWidget {
  final RecordModel member;

  const VorstandMembersEditTab({super.key, required this.member});

  @override
  State<VorstandMembersEditTab> createState() => _VorstandMembersEditTabState();
}

class _VorstandMembersEditTabState extends State<VorstandMembersEditTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController forenameController;
  late TextEditingController surnameController;
  late TextEditingController emailController;
  final passwordController = TextEditingController();
  late TextEditingController clubIdController;
  late TextEditingController phoneController;
  late TextEditingController mobileController;
  late TextEditingController ibanController;
  late TextEditingController bicController;
  late TextEditingController bankNameController;
  late TextEditingController bankOwnerController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    forenameController = TextEditingController(
      text: m.getStringValue('forename'),
    );
    surnameController = TextEditingController(
      text: m.getStringValue('surname'),
    );
    emailController = TextEditingController(text: m.getStringValue('email'));
    clubIdController = TextEditingController(text: m.getStringValue('club_id'));
    phoneController = TextEditingController(text: m.getStringValue('phone'));
    mobileController = TextEditingController(text: m.getStringValue('mobile'));
    ibanController = TextEditingController(text: m.getStringValue('iban'));
    bicController = TextEditingController(text: m.getStringValue('bic'));
    bankNameController = TextEditingController(
      text: m.getStringValue('bank_name'),
    );
    bankOwnerController = TextEditingController(
      text: m.getStringValue('bank_owner'),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final body = {
      "forename": forenameController.text.trim(),
      "surname": surnameController.text.trim(),
      "email": emailController.text.trim(),
      "club_id": clubIdController.text.trim(),
      "phone": phoneController.text.trim(),
      "mobile": mobileController.text.trim(),
      "iban": ibanController.text.trim(),
      "bic": bicController.text.trim(),
      "bank_name": bankNameController.text.trim(),
      "bank_owner": bankOwnerController.text.trim(),
    };

    final newPassword = passwordController.text.trim();
    if (newPassword.isNotEmpty) {
      body["password"] = newPassword;
      body["passwordConfirm"] = newPassword;
    }

    try {
      await pb.collection('users').update(widget.member.id, body: body);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Mitglied aktualisiert.")));
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Fehler beim Aktualisieren: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aktualisierung fehlgeschlagen.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surname = widget.member.getStringValue('surname');

    return Scaffold(
      appBar: AppBar(
        title: Text("Mitglied bearbeiten: $surname"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: forenameController,
                decoration: const InputDecoration(labelText: "Vorname"),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Vorname erforderlich"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: surnameController,
                decoration: const InputDecoration(labelText: "Nachname"),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Nachname erforderlich"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "E-Mail"),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "E-Mail erforderlich"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: "Neues Passwort (optional)",
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: clubIdController,
                decoration: const InputDecoration(labelText: "Club-ID"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Telefon"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: mobileController,
                decoration: const InputDecoration(labelText: "Mobil"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: ibanController,
                decoration: const InputDecoration(labelText: "IBAN"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: bicController,
                decoration: const InputDecoration(labelText: "BIC"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: bankNameController,
                decoration: const InputDecoration(labelText: "Bankname"),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: bankOwnerController,
                decoration: const InputDecoration(labelText: "Kontoinhaber"),
              ),
              const SizedBox(height: 16),
              if (_saving) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
