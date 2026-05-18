import 'package:flutter/material.dart';

class VorstandBookingsTab extends StatelessWidget {
  final int permission; // 0–3

  const VorstandBookingsTab({super.key, required this.permission});

  @override
  Widget build(BuildContext context) {
    if (permission == 0) {
      return const Center(
        child: Text("Keine Berechtigung für Buchungen."),
      );
    }

    final List<String> rights = [
      "sehen",
      if (permission >= 2) "hinzufügen",
      if (permission >= 3) "entfernen",
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Buchungen",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Deine Rechte: ${rights.join(' < ')}",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            "Hier kannst du später Buchungen einsehen und bearbeiten.",
          ),
        ],
      ),
    );
  }
}
