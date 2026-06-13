import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'main.dart';

class OnboardingScreen extends StatefulWidget {
  final RecordModel user;
  final VoidCallback onFinished;

  const OnboardingScreen({
    super.key,
    required this.user,
    required this.onFinished,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late TextEditingController forenameController;
  late TextEditingController surnameController;
  late TextEditingController phoneController;
  late TextEditingController ibanController;
  late TextEditingController bicController;
  late TextEditingController bankNameController;
  late TextEditingController bankOwnerController;

  bool membershiprequest = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    forenameController =
        TextEditingController(text: widget.user.getStringValue('forename'));
    surnameController =
        TextEditingController(text: widget.user.getStringValue('surname'));
    phoneController =
        TextEditingController(text: widget.user.getStringValue('phone'));
    ibanController =
        TextEditingController(text: widget.user.getStringValue('iban'));
    bicController =
        TextEditingController(text: widget.user.getStringValue('bic'));
    bankNameController =
        TextEditingController(text: widget.user.getStringValue('bank_name'));
    bankOwnerController =
        TextEditingController(text: widget.user.getStringValue('bank_owner'));
    membershiprequest = widget.user.getBoolValue('membership_request');
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

  Future<void> _finish() async {
    final forename = forenameController.text.trim();
    final surname = surnameController.text.trim();
    final phone = phoneController.text.trim();
    final iban = ibanController.text.trim();
    final bic = bicController.text.trim();
    final bankName = bankNameController.text.trim();
    final bankOwner = bankOwnerController.text.trim();


    if (forename.isEmpty || surname.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bitte Vorname, Nachname und Telefonnummer ausfüllen."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await pb.collection('users').update(widget.user.id, body: {
        'forename': forename,
        'surname': surname,
        'phone': phone,
        'membership_request': membershiprequest,
        'onboarding_done': true,
        if (iban.isNotEmpty) 'iban': iban,
        if (bic.isNotEmpty) 'bic': bic,
        if (bankName.isNotEmpty) 'bank_name': bankName,
        if (bankOwner.isNotEmpty) 'bank_owner': bankOwner,
      });

      // Auth-Session aktualisieren, damit AuthWrapper das neue Flag sieht
      await pb.collection('users').authRefresh();

      if (!mounted) return;
      widget.onFinished();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Konnte Daten nicht speichern: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final email = widget.user.getStringValue('email');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Willkommen beim TC Möckmühl"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Schön, dass du da bist!",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Bevor es losgeht, brauchen wir ein paar Basisdaten und geben dir einen kurzen Überblick über die App.",
                    ),
                    const SizedBox(height: 16),

                    if (email.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.email, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            email,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),

                    _sectionTitle("1. Kontaktdaten"),
                    const Text(
                      "Diese Daten nutzen wir nur für die Vereinskommunikation (z.B. Rückfragen zu Buchungen oder Infos des Vorstands).",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Telefon / Mobil (mit +49 oder 0...)",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    _sectionTitle("2.1 Mitglied werden?"),
                    const Text(
                      "Möchtest du Mitglied im TC Möckmühl werden oder hast Interesse an weiteren Informationen zur Mitgliedschaft?",
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: membershiprequest,
                      onChanged: (v) =>
                          setState(() => membershiprequest = v),
                      title: const Text("Ich möchte Mitglied werden / habe Interesse"),
                      subtitle: const Text(
                        "Wir melden uns bei dir oder du sprichst uns einfach am Platz an.",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),

                    _sectionTitle("2.2 Bankverbindung (optional)"),
                    const Text(
                      "Wenn du hier deine Bankdaten einträgst, können wir dir ein SEPA‑Lastschriftmandat zuordnen. "
                      "Du kannst diese Daten später im Profil ändern oder löschen.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ibanController,
                      decoration: const InputDecoration(
                        labelText: "IBAN",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bicController,
                      decoration: const InputDecoration(
                        labelText: "BIC",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bankNameController,
                      decoration: const InputDecoration(
                        labelText: "Name der Bank",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bankOwnerController,
                      decoration: const InputDecoration(
                        labelText: "Abweichender Kontoinhaber",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    _sectionTitle("3. Kurz erklärt"),
                    const SizedBox(height: 4),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.home),
                        title: const Text("Startseite"),
                        subtitle: const Text(
                          "Neuigkeiten des Vereins, wichtige Hinweise und Schnellzugriff auf Funktionen.",
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_month),
                        title: const Text("Plätze buchen"),
                        subtitle: const Text(
                          "Unter „Plätze“ kannst du Einzelbuchungen und Abos anlegen, bearbeiten und stornieren.",
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_drink),
                        title: const Text("Getränke"),
                        subtitle: const Text(
                          "Erfassung von Getränken und ggf. weiteren Verkaufsartikeln im Clubheim.",
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text("Profil"),
                        subtitle: const Text(
                          "Hier verwaltest du deine persönlichen Daten, Bankverbindung und Zugangsdaten.",
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Du kannst deine Daten später jederzeit im Profil anpassen.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appFrontColor.value,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Los geht's"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
