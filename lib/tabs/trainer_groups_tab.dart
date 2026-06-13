import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart';

class TrainerGroupsTab extends StatefulWidget {
  const TrainerGroupsTab({super.key});

  @override
  State<TrainerGroupsTab> createState() => _TrainerGroupsTabState();
}

class _TrainerGroupsTabState extends State<TrainerGroupsTab> {
  List<RecordModel> groups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = pb.authStore.record as RecordModel;

      final result = await pb.collection('trainer_groups').getFullList(
        filter: 'trainer = "${user.id}"',
        sort: 'name',
        expand: 'members',
      );

      if (mounted) {
        setState(() => groups = result);
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Gruppen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _editGroup(RecordModel? group) async {
    final isEdit = group != null;
    final nameController = TextEditingController(
      text: isEdit ? group.getStringValue('name') : '',
    );
    final descriptionController = TextEditingController(
      text: isEdit ? group.getStringValue('description') : '',
    );
    final levelController = TextEditingController(
      text: isEdit ? group.getStringValue('level') : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Gruppe bearbeiten" : "Neue Gruppe"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Gruppenname"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration:
                    const InputDecoration(labelText: "Beschreibung"),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: levelController,
                decoration: const InputDecoration(
                  labelText: "Stufe",
                  hintText: "z.B. Anfänger, Fortgeschrittene, Elite",
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
              Navigator.pop(ctx);
              await _saveGroup(
                isEdit ? group.id : null,
                nameController.text,
                descriptionController.text,
                levelController.text,
              );
            },
            child: const Text("Speichern"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGroup(
    String? id,
    String name,
    String description,
    String level,
  ) async {
    try {
      final user = pb.authStore.record as RecordModel;
      final body = {
        'name': name,
        'description': description,
        'level': level,
        'trainer': user.id,
      };

      if (id != null) {
        await pb.collection('trainer_groups').update(id, body: body);
      } else {
        await pb.collection('trainer_groups').create(body: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? "Gruppe gespeichert." : "Gruppe erstellt."),
          ),
        );
        _loadGroups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Fehler: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteGroup(RecordModel group) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Gruppe löschen?"),
            content: Text(
              "Möchtest du die Gruppe '${group.getStringValue('name')}' wirklich löschen?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Löschen"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await pb.collection('trainer_groups').delete(group.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gruppe gelöscht.")),
        );
        _loadGroups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Fehler: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainingsgruppen"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? const Center(
                  child: Text("Keine Gruppen vorhanden."),
                )
              : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final memberCount = group.expand['members']?.length ?? 0;

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(memberCount.toString()),
                        ),
                        title: Text(group.getStringValue('name')),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.getStringValue('level')),
                            Text(
                              "$memberCount Mitglieder",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editGroup(group),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteGroup(group),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appFrontColor.value,
        onPressed: () => _editGroup(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
