import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../main.dart';
import '../services/notification_workflow_service.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileTab({super.key, required this.onLogout});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late RecordModel user;

  late TextEditingController forenameController;
  late TextEditingController surnameController;
  late TextEditingController phoneController;
  late TextEditingController ibanController;
  late TextEditingController bicController;
  late TextEditingController bankNameController;
  late TextEditingController bankOwnerController;

  bool _saving = false;
  bool _dirty = false;

  void _onFieldChanged() {
    final hasChanges = _hasUnsavedChanges();
    if (hasChanges != _dirty) {
      setState(() => _dirty = hasChanges);
    }
  }

  @override
  void initState() {
    super.initState();
    final model = pb.authStore.model;
    if (model == null) {
      // Fallback – sollte eigentlich nicht vorkommen, da Profil nur bei Login
      throw StateError("Kein Benutzer angemeldet");
    }
    user = model as RecordModel;

    forenameController = TextEditingController(
      text: user.getStringValue('forename'),
    );
    surnameController = TextEditingController(
      text: user.getStringValue('surname'),
    );
    phoneController = TextEditingController(text: user.getStringValue('phone'));
    ibanController = TextEditingController(text: user.getStringValue('iban'));
    bicController = TextEditingController(text: user.getStringValue('bic'));
    bankNameController = TextEditingController(
      text: user.getStringValue('bank_name'),
    );
    bankOwnerController = TextEditingController(
      text: user.getStringValue('bank_owner'),
    );

    // Listen for changes to detect unsaved edits
    forenameController.addListener(_onFieldChanged);
    surnameController.addListener(_onFieldChanged);
    phoneController.addListener(_onFieldChanged);
    ibanController.addListener(_onFieldChanged);
    bicController.addListener(_onFieldChanged);
    bankNameController.addListener(_onFieldChanged);
    bankOwnerController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    forenameController.dispose();
    surnameController.dispose();
    phoneController.dispose();
    ibanController.dispose();
    bicController.dispose();
    bankNameController.dispose();
    bankOwnerController.dispose();
    super.dispose();
  }

  bool _hasUnsavedChanges() {
    if (forenameController.text.trim() != user.getStringValue('forename'))
      return true;
    if (surnameController.text.trim() != user.getStringValue('surname'))
      return true;
    if (phoneController.text.trim() != user.getStringValue('phone'))
      return true;
    if (ibanController.text.trim() != user.getStringValue('iban')) return true;
    if (bicController.text.trim() != user.getStringValue('bic')) return true;
    if (bankNameController.text.trim() != user.getStringValue('bank_name'))
      return true;
    if (bankOwnerController.text.trim() != user.getStringValue('bank_owner'))
      return true;
    return false;
  }

  Future<String?> _showSaveDiscardDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nicht gespeicherte Änderungen"),
        content: const Text(
          "Du hast Änderungen, die nicht gespeichert wurden. Was möchtest du tun?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Verwerfen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetControllersFromUser() async {
    forenameController.text = user.getStringValue('forename');
    surnameController.text = user.getStringValue('surname');
    phoneController.text = user.getStringValue('phone');
    ibanController.text = user.getStringValue('iban');
    bicController.text = user.getStringValue('bic');
    bankNameController.text = user.getStringValue('bank_name');
    bankOwnerController.text = user.getStringValue('bank_owner');
    if (mounted) setState(() => _dirty = false);
  }

  Future<void> _reloadUserFromDatabase() async {
    try {
      final refreshed = await pb.collection('users').getOne(user.id);
      user = refreshed;
    } catch (e) {
      debugPrint("Fehler beim Laden des Profils aus der DB: $e");
    }
    await _resetControllersFromUser();
  }

  Future<void> _confirmAndPerform(VoidCallback action) async {
    if (!_hasUnsavedChanges()) {
      action();
      return;
    }

    final decision = await _showSaveDiscardDialog();
    if (decision == 'save') {
      await _saveProfile();
      action();
    } else if (decision == 'discard') {
      await _reloadUserFromDatabase();
      action();
    } else {
      // cancel -> do nothing
    }
  }

  /// Public helper used by parent widgets to confirm leaving the profile
  /// Returns true when navigation away is allowed (saved or discarded), false when cancelled.
  Future<bool> confirmLeave() async {
    if (!_hasUnsavedChanges()) return true;
    final decision = await _showSaveDiscardDialog();
    if (decision == 'save') {
      await _saveProfile();
      return true;
    }
    if (decision == 'discard') {
      await _reloadUserFromDatabase();
      return true;
    }
    return false;
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);

    final body = {
      "forename": forenameController.text.trim(),
      "surname": surnameController.text.trim(),
      "phone": phoneController.text.trim(),
      "iban": ibanController.text.trim(),
      "bic": bicController.text.trim(),
      "bank_name": bankNameController.text.trim(),
      "bank_owner": bankOwnerController.text.trim(),
    };

    try {
      final updated = await pb.collection('users').update(user.id, body: body);
      user = updated;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profil gespeichert.")));
      setState(() {});
    } catch (e) {
      debugPrint("Fehler beim Speichern des Profils: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speichern fehlgeschlagen.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeEmailUsername() async {
    final emailController = TextEditingController(
      text: user.getStringValue('email'),
    );
    final usernameController = TextEditingController(
      text: user.getStringValue('username'),
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("E‑Mail / Benutzername ändern"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: "E‑Mail"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: "Benutzername (optional)",
                  ),
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
              onPressed: () async {
                final email = emailController.text.trim();
                final username = usernameController.text.trim();

                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("E‑Mail darf nicht leer sein."),
                    ),
                  );
                  return;
                }

                final body = {
                  "email": email,
                  if (username.isNotEmpty) "username": username,
                };

                try {
                  final updated = await pb
                      .collection('users')
                      .update(user.id, body: body);
                  user = updated;
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("E‑Mail / Benutzername aktualisiert."),
                    ),
                  );
                  Navigator.pop(ctx);
                  setState(() {});
                } catch (e) {
                  debugPrint("Fehler beim Ändern von E‑Mail/Username: $e");
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Änderung fehlgeschlagen.")),
                  );
                }
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Passwort ändern"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: "Neues Passwort",
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: "Passwort bestätigen",
                  ),
                  obscureText: true,
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
              onPressed: () async {
                final pw = newPasswordController.text.trim();
                final pw2 = confirmPasswordController.text.trim();

                if (pw.isEmpty || pw2.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Bitte beide Passwort-Felder ausfüllen."),
                    ),
                  );
                  return;
                }
                if (pw != pw2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Passwörter stimmen nicht überein."),
                    ),
                  );
                  return;
                }

                final body = {"password": pw, "passwordConfirm": pw};

                try {
                  await pb.collection('users').update(user.id, body: body);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Passwort geändert.")),
                  );
                  Navigator.pop(ctx);
                } catch (e) {
                  debugPrint("Fehler beim Passwort ändern: $e");
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Passwortänderung fehlgeschlagen."),
                    ),
                  );
                }
              },
              child: const Text("Speichern"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestMembership() async {
    final isMember = user.getBoolValue('membership');
    final hasRequested = user.getBoolValue('membership_request');

    if (isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Du bist bereits Mitglied.")),
      );
      return;
    }

    final action = hasRequested
        ? "Anfrage zurückziehen"
        : "Mitgliedschaft anfordern";
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(action),
            content: Text(
              hasRequested
                  ? "Möchtest du deine Mitgliedschaftsanfrage zurückziehen?"
                  : "Möchtest du eine Mitgliedschaft anfordern? Der Vorstand wird deine Anfrage überprüfen.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasRequested ? Colors.red : Colors.green,
                ),
                child: Text(hasRequested ? "Zurückziehen" : "Anfordern"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await pb
          .collection('users')
          .update(user.id, body: {'membership_request': !hasRequested});

      user = await pb.collection('users').getOne(user.id);

      if (!hasRequested) {
        await NotificationWorkflowService.createMembershipRequest(
          requester: user,
        );
      }

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasRequested
                ? "Anfrage zurückgezogen."
                : "Mitgliedschaftsanfrage gestellt.",
          ),
        ),
      );
    } catch (e) {
      debugPrint("Fehler bei Mitgliedschaftsanfrage: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Avatar-URL berechnen
    String? avatarUrl;
    final avatar = user.getStringValue('avatar');
    if (avatar.isNotEmpty) {
      avatarUrl = pb.files.getUrl(user, avatar).toString();
    }

    final forename = forenameController.text.trim();
    final surname = surnameController.text.trim();
    final fullName = [forename, surname].where((e) => e.isNotEmpty).join(" ");
    final email = user.getStringValue('email');
    final clubId = user.getStringValue('club_id');

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );

    return WillPopScope(
      onWillPop: () async {
        if (!_hasUnsavedChanges()) return true;
        final decision = await _showSaveDiscardDialog();
        if (decision == 'save') {
          await _saveProfile();
          return true;
        }
        if (decision == 'discard') {
          await _reloadUserFromDatabase();
          return true;
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Profil"),
          actions: [
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _saving ? null : _saveProfile,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kopfbereich mit Avatar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: appFrontColor.value.withValues(
                              alpha: 0.2,
                            ),
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? const Icon(Icons.person, size: 36)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName.isEmpty
                                      ? "Unbekannter Benutzer"
                                      : fullName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                if (clubId.isNotEmpty)
                                  Text(
                                    "Club-ID: $clubId",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Basisdaten (Name)
                    sectionTitle("Persönliche Daten"),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: forenameController,
                              decoration: const InputDecoration(
                                labelText: "Vorname",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: surnameController,
                              decoration: const InputDecoration(
                                labelText: "Nachname",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    // Kontakt (bearbeitbar)
                    sectionTitle("Kontakt"),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: "Telefon",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),

                    const Divider(),

                    // Bankdaten (bearbeitbar)
                    sectionTitle("Bankverbindung"),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: ibanController,
                        decoration: const InputDecoration(
                          labelText: "IBAN",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: bicController,
                        decoration: const InputDecoration(
                          labelText: "BIC",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: bankNameController,
                        decoration: const InputDecoration(
                          labelText: "Bankname",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: bankOwnerController,
                        decoration: const InputDecoration(
                          labelText: "Kontoinhaber",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),

                    const Divider(),

                    // Mitgliedschaft
                    sectionTitle("Mitgliedschaft"),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Card(
                        color: user.getBoolValue('membership')
                            ? Colors.green.shade50
                            : (user.getBoolValue('membership_request')
                                  ? Colors.orange.shade50
                                  : Colors.grey.shade100),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    user.getBoolValue('membership')
                                        ? Icons.check_circle
                                        : (user.getBoolValue(
                                                'membership_request',
                                              )
                                              ? Icons.schedule
                                              : Icons.block),
                                    color: user.getBoolValue('membership')
                                        ? Colors.green
                                        : (user.getBoolValue(
                                                'membership_request',
                                              )
                                              ? Colors.orange
                                              : Colors.grey),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    user.getBoolValue('membership')
                                        ? "Mitglied"
                                        : (user.getBoolValue(
                                                'membership_request',
                                              )
                                              ? "Anfrage ausstehend"
                                              : "Kein Mitglied"),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (user.getBoolValue('membership')) ...[
                                Text(
                                  "Seit ${DateFormat('dd.MM.yyyy', 'de_DE').format(DateTime.parse(user.created).toLocal())}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ] else ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: Icon(
                                      user.getBoolValue('membership_request')
                                          ? Icons.close
                                          : Icons.person_add,
                                    ),
                                    label: Text(
                                      user.getBoolValue('membership_request')
                                          ? "Anfrage zurückziehen"
                                          : "Mitgliedschaft anfordern",
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          user.getBoolValue(
                                            'membership_request',
                                          )
                                          ? Colors.red
                                          : appFrontColor.value,
                                    ),
                                    onPressed: _requestMembership,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Divider(),

                    // Aktionen: Email/Benutzername & Passwort
                    sectionTitle("Zugangsdaten"),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.alternate_email),
                              label: const Text("E‑Mail / Benutzername ändern"),
                              onPressed: _changeEmailUsername,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.lock),
                              label: const Text("Passwort ändern"),
                              onPressed: _changePassword,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Logout unten
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("Abmelden"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: () => _confirmAndPerform(widget.onLogout),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
