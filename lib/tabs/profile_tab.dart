import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart'; // Importiert die globale pb Instanz

class ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileTab({super.key, required this.onLogout});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late TextEditingController bankController;
  late TextEditingController phoneController;
  late RecordModel user;

  @override
  void initState() {
    super.initState();
    user = pb.authStore.model as RecordModel;
    bankController =
        TextEditingController(text: user.getStringValue('bank_details'));
    phoneController =
        TextEditingController(text: user.getStringValue('phone'));
  }

  @override
  void dispose() {
    bankController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarField = user.getStringValue('avatar');

    // Wenn in PocketBase kein Bild hinterlegt ist → Fallback mit Initialen
    final avatarUrl = avatarField.isEmpty
        ? "https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.getStringValue('name'))}"
        : "${pb.baseUrl}/api/files/users/${user.id}/$avatarField";

    return Scaffold(
      appBar: AppBar(title: const Text("Mein Profil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(avatarUrl),
            ),
            const SizedBox(height: 20),
            Text(
              user.getStringValue('name'),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _infoTile("Vereins-ID (Fix)", user.getStringValue('club_id'),
                Icons.badge),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: "Telefon",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bankController,
              decoration: const InputDecoration(
                labelText: "IBAN",
                prefixIcon: Icon(Icons.account_balance),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await pb.collection('users').update(user.id, body: {
                  "bank_details": bankController.text,
                  "phone": phoneController.text,
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Gespeichert!")),
                );
              },
              child: const Text("Daten aktualisieren"),
            ),
            TextButton(
              onPressed: widget.onLogout,
              child: const Text(
                "Abmelden",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value.isEmpty ? "Nicht zugewiesen" : value,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
