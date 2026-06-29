import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class VorstandMembershipTab extends StatefulWidget {
  final int permission; // Should check perm_board_member >= 3 to manage

  const VorstandMembershipTab({super.key, required this.permission});

  @override
  State<VorstandMembershipTab> createState() => _VorstandMembershipTabState();
}

class _VorstandMembershipTabState extends State<VorstandMembershipTab> {
  List<RecordModel> membershipRequests = [];
  List<RecordModel> members = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembershipData();
  }

  Future<void> _loadMembershipData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // Load pending membership requests
      final requestsRes = await pb.collection('users').getFullList(
        filter: 'membership_request = true && membership = false',
        sort: '-created',
      );

      // Load current members
      final membersRes = await pb.collection('users').getFullList(
        filter: 'membership = true',
        sort: 'surname,forename',
      );

      if (mounted) {
        setState(() {
          membershipRequests = requestsRes;
          members = membersRes;
        });
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Mitgliedsdaten: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _approveMembershipRequest(RecordModel user) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Mitgliedschaft genehmigen?"),
            content: Text(
              "Möchtest du ${user.getStringValue('forename')} ${user.getStringValue('surname')} als Mitglied akzeptieren?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Ablehnen"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Akzeptieren"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await pb.collection('users').update(user.id, body: {
        'membership': true,
        'membership_request': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mitgliedschaft genehmigt.")),
        );
        _loadMembershipData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectMembershipRequest(RecordModel user) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Mitgliedschaftsanfrage ablehnen?"),
            content: Text(
              "Möchtest du die Anfrage von ${user.getStringValue('forename')} ${user.getStringValue('surname')} ablehnen?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Ablehnen"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await pb.collection('users').update(user.id, body: {
        'membership': false,
        'membership_request': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Anfrage abgelehnt.")),
        );
        _loadMembershipData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeMembership(RecordModel user) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Mitgliedschaft entfernen?"),
            content: Text(
              "Möchtest du ${user.getStringValue('forename')} ${user.getStringValue('surname')} aus der Mitgliederliste entfernen?",
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
      await pb.collection('users').update(user.id, body: {
        'membership': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mitgliedschaft entfernt.")),
        );
        _loadMembershipData();
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
    final user = pb.authStore.record as RecordModel;
    final isAppAdmin = user.getBoolValue('auth_admin_app');
    final canManageMembership =
        isAppAdmin || (widget.permission >= 3 || widget.permission >= 4); // permission level 3+ for management

    if (!canManageMembership) {
      return const Scaffold(
        body: Center(
          child: Text("Keine Berechtigung zur Verwaltung der Mitgliedschaften."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mitgliedschaften"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(
                        text:
                            "Anfragen (${membershipRequests.length})",
                      ),
                      Tab(
                        text: "Mitglieder (${members.length})",
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Membership Requests Tab
                        membershipRequests.isEmpty
                            ? const Center(
                                child: Text("Keine offenen Mitgliedschaftsanfragen."),
                              )
                            : ListView.builder(
                                itemCount: membershipRequests.length,
                                itemBuilder: (context, index) {
                                  final req = membershipRequests[index];
                                  final created =
                                      DateTime.parse(req.created).toLocal();

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.person_add,
                                          color: Colors.orange),
                                      title: Text(
                                        "${req.getStringValue('forename')} ${req.getStringValue('surname')}",
                                      ),
                                      subtitle: Text(
                                        "Angefordert: ${DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(created)}",
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.check,
                                                color: Colors.green),
                                            tooltip: "Genehmigen",
                                            onPressed: () =>
                                                _approveMembershipRequest(req),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close,
                                                color: Colors.red),
                                            tooltip: "Ablehnen",
                                            onPressed: () =>
                                                _rejectMembershipRequest(req),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                        // Members Tab
                        members.isEmpty
                            ? const Center(
                                child: Text("Keine Mitglieder vorhanden."),
                              )
                            : ListView.builder(
                                itemCount: members.length,
                                itemBuilder: (context, index) {
                                  final member = members[index];

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.verified,
                                          color: Colors.green),
                                      title: Text(
                                        "${member.getStringValue('forename')} ${member.getStringValue('surname')}",
                                      ),
                                      subtitle: Text(
                                        member.getStringValue('email'),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        tooltip: "Mitgliedschaft entfernen",
                                        onPressed: () =>
                                            _removeMembership(member),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
