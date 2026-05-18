import 'package:flutter/material.dart';
import '../main.dart';

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Startwerte aus den globalen Notifiers
    _appBackColor = appBackColor.value;
    _appFrontColor = appFrontColor.value;
    _ownColor = ownBookingColor.value;
    _otherColor = otherBookingColor.value;
  }

  Future<void> _saveColors() async {
    setState(() => _saving = true);
    try {
      await pb.collection('settings').update(settingsRecordId, body: {
        'app_colour_back': colorToHex(_appBackColor),
        'app_colour_front': colorToHex(_appFrontColor),
        'court_color_own': colorToHex(_ownColor),
        'court_color_other': colorToHex(_otherColor),
      });

      // Globale Notifier aktualisieren -> ganze App färbt sich um
      appBackColor.value = _appBackColor;
      appFrontColor.value = _appFrontColor;
      ownBookingColor.value = _ownColor;
      otherBookingColor.value = _otherColor;

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
          title: const Text("Hintergrundfarbe (app_colour_back)"),
          subtitle: const Text("Grund-Hintergrund der App"),
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
          title: const Text("Akzentfarbe / Vordergrund (app_colour_front)"),
          subtitle: const Text("Farben für Buttons, AppBar, Hervorhebungen"),
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
        const Divider(),

        const SizedBox(height: 16),
        const Text(
          "Platzbelegung",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Eigene Buchungen
        ListTile(
          leading: CircleAvatar(
            backgroundColor: _ownColor.withOpacity(0.7),
          ),
          title: const Text("Eigene Buchungen"),
          subtitle: const Text("Farbe für selbst oder als Spieler gebuchte Plätze"),
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
            backgroundColor: _otherColor.withOpacity(0.7),
          ),
          title: const Text("Fremde Buchungen"),
          subtitle: const Text("Farbe für von anderen gebuchte Plätze"),
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
        const SizedBox(height: 24),

        // Speichern-Button
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
            label: const Text("Farben dauerhaft speichern"),
          ),
        ),
      ],
    );
  }
}
