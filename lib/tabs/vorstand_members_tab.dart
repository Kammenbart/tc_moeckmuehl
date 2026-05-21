import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../main.dart';

/// (Optional) alter Dialog – wird aktuell nicht benutzt, kann später gelöscht werden.
Future<void> showMemberEditDialog(
  BuildContext context, {
  RecordModel? member,
  required int permission,
}) async {
  final isEdit = member != null;

  final nameController =
      TextEditingController(text: isEdit ? member.getStringValue('name') : '');
  final emailController =
      TextEditingController(text: isEdit ? member.getStringValue('email') : '');
  final passwordController = TextEditingController();
  final clubIdController = TextEditingController(
      text: isEdit ? member.getStringValue('club_id') : '');
  final ibanController = TextEditingController(
      text: isEdit ? member.getStringValue('iban') : '');
  final bicController = TextEditingController(
      text: isEdit ? member.getStringValue('bic') : '');
  final bankNameController = TextEditingController(
      text: isEdit ? member.getStringValue('bank_name') : '');
  final bankOwnerController = TextEditingController(
      text: isEdit ? member.getStringValue('bank_owner') : '');
  final phoneController = TextEditingController(
      text: isEdit ? member.getStringValue('phone') : '');
  final mobileController = TextEditingController(
      text: isEdit ? member.getStringValue('mobile') : '');

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
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
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
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final password = passwordController.text.trim();

                    if (name.isEmpty || email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Name und E-Mail dürfen nicht leer sein."),
                        ),
                      );
                      return;
                    }

                    if (!isEdit && password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Für neue Mitglieder ist ein Passwort nötig."),
                        ),
                      );
                      return;
                    }

                    final body = {
                      "name": name,
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
                        await pb.collection('users').update(member.id, body: body);
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
                            content:
                                Text("Speichern fehlgeschlagen. Bitte prüfen."),
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
  const VorstandMembersTab({super.key, required this.permission});

  @override
  State<VorstandMembersTab> createState() => _VorstandMembersTabState();
}

class _VorstandMembersTabState extends State<VorstandMembersTab> {
  List<RecordModel> members = [];
  List<RecordModel> filteredMembers = [];
  bool isLoading = true;
  String searchQuery = "";
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      members = await pb.collection('users').getFullList(sort: 'name');
      filteredMembers = members;
    } catch (e) {
      debugPrint("Fehler beim Laden: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _filterMembers(String query) {
    setState(() {
      searchQuery = query;
      filteredMembers = members.where((m) {
        final name = m.getStringValue('name').toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _handleDelete(RecordModel targetUser) async {
    if (widget.permission >= 3) {
      final confirm = await _showConfirmDialog(
        "Mitglied löschen",
        "Möchtest du ${targetUser.getStringValue('name')} wirklich unwiderruflich löschen?",
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
        await pb.collection('member_delete_requests').create(body: {
          "requested_by": pb.authStore.model!.id,
          "target_user": targetUser.id,
          "status": "pending",
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Anfrage gesendet.")),
          );
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              onChanged: _filterMembers,
              decoration: const InputDecoration(
                labelText: "Mitglieder suchen...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final m = filteredMembers[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(m.getStringValue('name')),
                  subtitle: Text(m.getStringValue('email')),
                  onTap: widget.permission >= 2
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
                      if (widget.permission >= 4)
                        IconButton(
                          icon: const Icon(Icons.security, color: Colors.blue),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VorstandMembersPermTab(
                                  member: m,
                                ),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      if (widget.permission >= 2)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _handleDelete(m),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.permission >= 2
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

/// Rechte-Screen für ein Mitglied
class VorstandMembersPermTab extends StatefulWidget {
  final RecordModel member;

  const VorstandMembersPermTab({super.key, required this.member});

  @override
  State<VorstandMembersPermTab> createState() =>
      _VorstandMembersPermTabState();
}

class _VorstandMembersPermTabState extends State<VorstandMembersPermTab> {
  late bool authVorstand;
  late bool authTrainer;
  late bool authAdmin;

  late int permMember;
  late int permKasse;
  late int permBooking;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    authVorstand = m.getBoolValue('auth_vorstand');
    authTrainer = m.getBoolValue('auth_trainer');
    authAdmin = m.getBoolValue('auth_admin');

    permMember = m.getIntValue('perm_vorstand_member');
    permKasse = m.getIntValue('perm_vorstand_kasse');
    permBooking = m.getIntValue('perm_vorstand_booking');
  }

  Future<void> _save() async {
    final body = {
      "auth_vorstand": authVorstand,
      "auth_trainer": authTrainer,
      "auth_admin": authAdmin,
      "perm_vorstand_member": permMember,
      "perm_vorstand_kasse": permKasse,
      "perm_vorstand_booking": permBooking,
    };

    try {
      await pb.collection('users').update(widget.member.id, body: body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rechte gespeichert.")),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Fehler beim Speichern der Rechte: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Speichern der Rechte fehlgeschlagen."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.member.getStringValue('name');

    return Scaffold(
      appBar: AppBar(
        title: Text('Rechte: $name'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Rollen",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Kein Zugriff")),
                DropdownMenuItem(value: 1, child: Text("Nur ansehen")),
                DropdownMenuItem(
                  value: 2,
                  child: Text("Ansehen, hinzufügen & bearbeiten"),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text("Wie oben + löschen"),
                ),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
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

  final nameController = TextEditingController();
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
      "name": nameController.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mitglied angelegt.")),
      );
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
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Name erforderlich" : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "E-Mail"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "E-Mail erforderlich" : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: "Passwort"),
                obscureText: true,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Passwort erforderlich" : null,
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
  State<VorstandMembersEditTab> createState() =>
      _VorstandMembersEditTabState();
}

class _VorstandMembersEditTabState extends State<VorstandMembersEditTab> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
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
    nameController =
        TextEditingController(text: m.getStringValue('name'));
    emailController =
        TextEditingController(text: m.getStringValue('email'));
    clubIdController =
        TextEditingController(text: m.getStringValue('club_id'));
    phoneController =
        TextEditingController(text: m.getStringValue('phone'));
    mobileController =
        TextEditingController(text: m.getStringValue('mobile'));
    ibanController =
        TextEditingController(text: m.getStringValue('iban'));
    bicController =
        TextEditingController(text: m.getStringValue('bic'));
    bankNameController =
        TextEditingController(text: m.getStringValue('bank_name'));
    bankOwnerController =
        TextEditingController(text: m.getStringValue('bank_owner'));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final body = {
      "name": nameController.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mitglied aktualisiert.")),
      );
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
    final name = widget.member.getStringValue('name');

    return Scaffold(
      appBar: AppBar(
        title: Text("Mitglied bearbeiten: $name"),
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
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Name erforderlich" : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "E-Mail"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "E-Mail erforderlich" : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                    labelText: "Neues Passwort (optional)"),
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