import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart';

class TrainerServicesTab extends StatefulWidget {
  const TrainerServicesTab({super.key});

  @override
  State<TrainerServicesTab> createState() => _TrainerServicesTabState();
}

class _TrainerServicesTabState extends State<TrainerServicesTab> {
  List<RecordModel> services = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = pb.authStore.record as RecordModel;

      final result = await pb.collection('trainer_services').getFullList(
        filter: 'trainer = "${user.id}"',
        sort: 'name',
      );

      if (mounted) {
        setState(() => services = result);
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Leistungen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _editService(RecordModel? service) async {
    final isEdit = service != null;
    final nameController = TextEditingController(
      text: isEdit ? service.getStringValue('name') : '',
    );
    final descriptionController = TextEditingController(
      text: isEdit ? service.getStringValue('description') : '',
    );
    final priceController = TextEditingController(
      text: isEdit ? service.getDoubleValue('price').toString() : '',
    );
    final unitController = TextEditingController(
      text: isEdit ? service.getStringValue('unit') : 'Stunde',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Leistung bearbeiten" : "Neue Leistung"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Leistungsname"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: "Beschreibung"),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: "Preis (€)",
                  hintText: "50.00",
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: "Einheit",
                  hintText: "Stunde, Sitzung, etc.",
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
              await _saveService(
                isEdit ? service.id : null,
                nameController.text,
                descriptionController.text,
                priceController.text,
                unitController.text,
              );
            },
            child: const Text("Speichern"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveService(
    String? id,
    String name,
    String description,
    String priceStr,
    String unit,
  ) async {
    try {
      final price = double.tryParse(priceStr.replaceAll(',', '.')) ?? 0.0;
      final user = pb.authStore.record as RecordModel;

      final body = {
        'name': name,
        'description': description,
        'price': price,
        'unit': unit,
        'trainer': user.id,
      };

      if (id != null) {
        await pb.collection('trainer_services').update(id, body: body);
      } else {
        await pb.collection('trainer_services').create(body: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(id != null ? "Leistung gespeichert." : "Leistung erstellt."),
          ),
        );
        _loadServices();
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

  Future<void> _deleteService(RecordModel service) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Leistung löschen?"),
            content: Text(
              "Möchtest du '${service.getStringValue('name')}' wirklich löschen?",
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
      await pb.collection('trainer_services').delete(service.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Leistung gelöscht.")),
        );
        _loadServices();
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
        title: const Text("Leistungsverzeichnis"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : services.isEmpty
              ? const Center(
                  child: Text("Keine Leistungen vorhanden."),
                )
              : ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(service.getStringValue('name')),
                        subtitle: Text(
                          "€ ${service.getDoubleValue('price').toStringAsFixed(2)} / ${service.getStringValue('unit')}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editService(service),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteService(service),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appFrontColor.value,
        onPressed: () => _editService(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
