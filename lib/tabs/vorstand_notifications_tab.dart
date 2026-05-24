import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class VorstandNotificationsTab extends StatefulWidget {
  const VorstandNotificationsTab({super.key});

  @override
  State<VorstandNotificationsTab> createState() =>
      _VorstandNotificationsTabState();
}

class _VorstandNotificationsTabState extends State<VorstandNotificationsTab> {
  List<RecordModel> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final userId = pb.authStore.model.id;

    try {
      final res = await pb.collection('notifications').getFullList(
            filter: 'user = "$userId"',
            sort: '-created',
          );
      setState(() {
        items = res;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden der Mitteilungen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'offen':
        return Colors.red;
      case 'info':
        return Colors.blue;
      case 'erledigt':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return const Center(
        child: Text("Keine Mitteilungen vorhanden."),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final n = items[i];
          final title = n.getStringValue('title');
          final message = n.getStringValue('message');
          final status = n.getStringValue('status');

          final created =
              DateTime.parse(n.getStringValue('created')).toLocal();
          final createdStr = DateFormat(
            'EEEE, dd.MM.yyyy HH:mm',
            'de_DE',
          ).format(created);

          return Card(
            child: ListTile(
              title: Text(title.isEmpty ? "(Ohne Titel)" : title),
              subtitle: Text(createdStr),
              trailing: Chip(
                label: Text(status.isEmpty ? "info" : status),
                backgroundColor:
                    _statusColor(status).withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(title.isEmpty ? "(Ohne Titel)" : title),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Status: $status"),
                        const SizedBox(height: 8),
                        Text(message),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Schließen"),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
