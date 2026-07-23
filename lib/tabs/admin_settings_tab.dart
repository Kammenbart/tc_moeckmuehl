import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../main.dart';
import '../services/settings_service.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  late Color _appBackColor;
  late Color _appFrontColor;
  late Color _ownColor;
  late Color _otherColor;
  late Color _eventColor;
  late String _supportMail;
  bool _saving = false;
  bool _isTesting = false;
  late TextEditingController _supportMailController;
  late TextEditingController _smtpHostController;
  late TextEditingController _smtpPortController;
  late TextEditingController _smtpUserController;
  late TextEditingController _smtpPassController;
  bool _smtpSecure = true;

  @override
  void initState() {
    super.initState();
    // Startwerte aus den globalen Notifiers
    _appBackColor = appBackColor.value;
    _appFrontColor = appFrontColor.value;
    _ownColor = ownBookingColor.value;
    _otherColor = otherBookingColor.value;
    _eventColor = eventBookingColor.value;
    _supportMail = adminFeedbackEmail;
    _supportMailController = TextEditingController(text: _supportMail);
    _smtpHostController = TextEditingController();
    _smtpPortController = TextEditingController();
    _smtpUserController = TextEditingController();
    _smtpPassController = TextEditingController();
    // load smtp settings asynchronously
    _loadSmtpSettings();
  }

  @override
  void dispose() {
    _supportMailController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUserController.dispose();
    _smtpPassController.dispose();
    super.dispose();
  }

  Future<void> _loadSmtpSettings() async {
    final settingsSvc = AppSettingsService(pb);
    final vals = await settingsSvc.loadSettings([
      'smtp_host',
      'smtp_port',
      'smtp_username',
      'smtp_password',
      'smtp_secure',
    ]);

    if (!mounted) return;
    setState(() {
      _smtpHostController.text = vals['smtp_host'] ?? '';
      _smtpPortController.text = vals['smtp_port'] ?? '';
      _smtpUserController.text = vals['smtp_username'] ?? '';
      _smtpPassController.text = vals['smtp_password'] ?? '';
      _smtpSecure = (vals['smtp_secure'] ?? 'true').toLowerCase() == 'true';
    });
  }

  Future<void> _testSmtpSettings() async {
    if (_smtpHostController.text.trim().isEmpty ||
        _smtpPortController.text.trim().isEmpty ||
        _smtpUserController.text.trim().isEmpty ||
        _smtpPassController.text.isEmpty ||
        _supportMail.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte fülle SMTP-Daten und Support-Mail aus, bevor du testest.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);
    try {
      final settingsSvc = AppSettingsService(pb);
      await settingsSvc.saveSettings({
        'app_support_mail': _supportMail,
        'smtp_host': _smtpHostController.text.trim(),
        'smtp_port': _smtpPortController.text.trim(),
        'smtp_username': _smtpUserController.text.trim(),
        'smtp_password': _smtpPassController.text,
        'smtp_secure': _smtpSecure ? 'true' : 'false',
      });

      final port = int.tryParse(_smtpPortController.text.trim()) ?? 587;
      final smtp = SmtpServer(
        _smtpHostController.text.trim(),
        port: port,
        username: _smtpUserController.text.trim(),
        password: _smtpPassController.text,
        ssl: _smtpSecure,
      );

      final message = Message()
        ..from = Address(_smtpUserController.text.trim(), 'TC Möckmühl Test')
        ..recipients.add(_supportMail)
        ..subject = 'SMTP Testnachricht'
        ..text = 'Dies ist eine Testmail aus der TC Möckmühl Admin-Einstellung.';

      await send(message, smtp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMTP-Test erfolgreich: Mail wurde versendet.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SMTP-Test fehlgeschlagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _saveColors() async {
    setState(() => _saving = true);
    try {
      final settingsSvc = AppSettingsService(pb);
      await settingsSvc.saveSettings({
        'app_colour_back': colorToHex(_appBackColor),
        'app_colour_front': colorToHex(_appFrontColor),
        'court_color_own': colorToHex(_ownColor),
        'court_color_other': colorToHex(_otherColor),
        'court_color_event': colorToHex(_eventColor),
        'app_support_mail': _supportMail,
        'smtp_host': _smtpHostController.text.trim(),
        'smtp_port': _smtpPortController.text.trim(),
        'smtp_username': _smtpUserController.text.trim(),
        'smtp_password': _smtpPassController.text,
        'smtp_secure': _smtpSecure ? 'true' : 'false',
      });

      // Globale Notifier aktualisieren -> ganze App färbt sich um
      appBackColor.value = _appBackColor;
      appFrontColor.value = _appFrontColor;
      ownBookingColor.value = _ownColor;
      otherBookingColor.value = _otherColor;
      eventBookingColor.value = _eventColor;
      adminFeedbackEmail = _supportMail;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farben gespeichert')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickColor({
    required Color initial,
    required ValueChanged<Color> onChanged,
  }) async {
    Color tempColor = initial;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Farbe wählen'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 40,
                    color: tempColor,
                  ),
                  const SizedBox(height: 16),
                  _slider(
                    label: "Rot",
                    value: tempColor.red.toDouble(),
                    onChanged: (v) {
                      setDialogState(() {
                        tempColor = tempColor.withRed(v.toInt());
                      });
                    },
                  ),
                  _slider(
                    label: "Grün",
                    value: tempColor.green.toDouble(),
                    onChanged: (v) {
                      setDialogState(() {
                        tempColor = tempColor.withGreen(v.toInt());
                      });
                    },
                  ),
                  _slider(
                    label: "Blau",
                    value: tempColor.blue.toDouble(),
                    onChanged: (v) {
                      setDialogState(() {
                        tempColor = tempColor.withBlue(v.toInt());
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                onChanged(tempColor);
                Navigator.pop(context);
              },
              child: const Text('Übernehmen'),
            ),
          ],
        );
      },
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label (${value.toInt()})"),
        Slider(
          min: 0,
          max: 255,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "App-Farben",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Hintergrundfarbe
        ListTile(
          leading: CircleAvatar(backgroundColor: _appBackColor),
          title: const Text("Hintergrundfarbe"),
          subtitle: const Text("Hintergrund der App"),
          trailing: TextButton(
            onPressed: () async {
              await _pickColor(
                initial: _appBackColor,
                onChanged: (c) {
                  setState(() {
                    _appBackColor = c;
                  });
                },
              );
            },
            child: const Text("Wählen"),
          ),
        ),
        const Divider(),

        // Vordergrund / Akzent
        ListTile(
          leading: CircleAvatar(backgroundColor: _appFrontColor),
          title: const Text("Vordergrundfarbe"),
          subtitle: const Text("Buttons, Schrift, Hervorhebungen"),
          trailing: TextButton(
            onPressed: () async {
              await _pickColor(
                initial: _appFrontColor,
                onChanged: (c) {
                  setState(() {
                    _appFrontColor = c;
                  });
                },
              );
            },
            child: const Text("Wählen"),
          ),
        ),

        const SizedBox(height: 16),
        const Text(
          "Platzbelegung",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Eigene Buchungen
        ListTile(
          leading: CircleAvatar(
            backgroundColor: _ownColor.withValues(alpha: 0.7),
          ),
          title: const Text("Eigene Buchungen"),
          trailing: TextButton(
            onPressed: () async {
              await _pickColor(
                initial: _ownColor,
                onChanged: (c) {
                  setState(() {
                    _ownColor = c;
                  });
                },
              );
            },
            child: const Text("Wählen"),
          ),
        ),
        const Divider(),

        // Fremde Buchungen
        ListTile(
          leading: CircleAvatar(
            backgroundColor: _otherColor.withValues(alpha: 0.7),
          ),
          title: const Text("Fremde Buchungen"),
          trailing: TextButton(
            onPressed: () async {
              await _pickColor(
                initial: _otherColor,
                onChanged: (c) {
                  setState(() {
                    _otherColor = c;
                  });
                },
              );
            },
            child: const Text("Wählen"),
          ),
        ),
        const Divider(),

        // Ereignisbuchungen
        ListTile(
          leading: CircleAvatar(
            backgroundColor: _eventColor.withValues(alpha: 0.7),
          ),
          title: const Text("Ereignisbuchungen"),
          trailing: TextButton(
            onPressed: () async {
              await _pickColor(
                initial: _eventColor,
                onChanged: (c) {
                  setState(() {
                    _eventColor = c;
                  });
                },
              );
            },
            child: const Text("Wählen"),
          ),
        ),

        const SizedBox(height: 16),
        const Text(
          "Mails",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        // Speichern-Button
        const SizedBox(height: 16),

        // Support-Mail
        ListTile(
          leading: const Icon(Icons.mail_outline),
          title: const Text('Verbesserungsvorschläge'),
          subtitle: TextField(
            controller: _supportMailController,
            decoration: const InputDecoration(hintText: 'support@beispiel.de'),
            onChanged: (v) => _supportMail = v.trim(),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'SMTP Einstellungen',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _smtpHostController,
          decoration: const InputDecoration(labelText: 'SMTP Host'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _smtpPortController,
          decoration: const InputDecoration(labelText: 'SMTP Port'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _smtpUserController,
          decoration: const InputDecoration(labelText: 'SMTP Benutzer'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _smtpPassController,
          decoration: const InputDecoration(labelText: 'SMTP Passwort'),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('SSL/TLS'),
          value: _smtpSecure,
          onChanged: (v) => setState(() => _smtpSecure = v),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isTesting ? null : _testSmtpSettings,
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: const Text('SMTP testen'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _saveColors,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: const Text('Einstellungen speichern'),
          ),
        ),
      ],
    );
  }
}
