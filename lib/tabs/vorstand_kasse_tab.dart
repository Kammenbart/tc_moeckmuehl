import 'package:flutter/material.dart';

class VorstandKasseTab extends StatelessWidget {
  final int permission; // 0–3

  const VorstandKasseTab({super.key, required this.permission});

  @override
  Widget build(BuildContext context) {
    if (permission == 0) {
      return const Center(
        child: Text("Keine Berechtigung für Kasse."),
      );
    }

    final List<String> rights = [
      "Rechnung einreichen",
      if (permission >= 2) "Rechnung freigeben",
      if (permission >= 3) "als erledigt markieren",
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Kasse",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Deine Rechte: ${rights.join(' < ')}",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            "Hier kannst du später Rechnungen verwalten.",
          ),
        ],
      ),
    );
  }
}
