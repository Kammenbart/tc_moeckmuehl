import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class TrainerCustomersTab extends StatefulWidget {
  const TrainerCustomersTab({super.key});

  @override
  State<TrainerCustomersTab> createState() => _TrainerCustomersTabState();
}

class _TrainerCustomersTabState extends State<TrainerCustomersTab> {
  List<RecordModel> customers = [];
  List<RecordModel> filteredCustomers = [];
  bool isLoading = true;
  String searchQuery = "";
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = pb.authStore.record as RecordModel;

      final result = await pb.collection('trainer_customers').getFullList(
        filter: 'trainer = "${user.id}"',
        sort: 'surname,forename',
      );

      if (mounted) {
        setState(() {
          customers = result;
          filteredCustomers = result;
        });
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Kunden: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _filterCustomers() {
    setState(() {
      filteredCustomers = customers.where((c) {
        final name =
            "${c.getStringValue('forename')} ${c.getStringValue('surname')}"
                .toLowerCase();
        final email = c.getStringValue('email').toLowerCase();
        final phone = c.getStringValue('phone').toLowerCase();
        final search = searchQuery.toLowerCase();

        return name.contains(search) ||
            email.contains(search) ||
            phone.contains(search);
      }).toList();
    });
  }

  Future<void> _editCustomer(RecordModel? customer) async {
    final isEdit = customer != null;
    final forenameController = TextEditingController(
      text: isEdit ? customer.getStringValue('forename') : '',
    );
    final surnameController = TextEditingController(
      text: isEdit ? customer.getStringValue('surname') : '',
    );
    final emailController = TextEditingController(
      text: isEdit ? customer.getStringValue('email') : '',
    );
    final phoneController = TextEditingController(
      text: isEdit ? customer.getStringValue('phone') : '',
    );
    final mobileController = TextEditingController(
      text: isEdit ? customer.getStringValue('mobile') : '',
    );
    final addressController = TextEditingController(
      text: isEdit ? customer.getStringValue('address') : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Kunde bearbeiten" : "Neuer Kunde"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: forenameController,
                decoration: const InputDecoration(labelText: "Vorname"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: surnameController,
                decoration: const InputDecoration(labelText: "Nachname"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "E-Mail"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Telefon"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: mobileController,
                decoration: const InputDecoration(labelText: "Mobil"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: "Adresse"),
                maxLines: 2,
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
              await _saveCustomer(
                isEdit ? customer.id : null,
                forenameController.text,
                surnameController.text,
                emailController.text,
                phoneController.text,
                mobileController.text,
                addressController.text,
              );
            },
            child: const Text("Speichern"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCustomer(
    String? id,
    String forename,
    String surname,
    String email,
    String phone,
    String mobile,
    String address,
  ) async {
    try {
      final user = pb.authStore.record as RecordModel;
      final body = {
        'forename': forename,
        'surname': surname,
        'email': email,
        'phone': phone,
        'mobile': mobile,
        'address': address,
        'trainer': user.id,
      };

      if (id != null) {
        await pb.collection('trainer_customers').update(id, body: body);
      } else {
        await pb.collection('trainer_customers').create(body: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? "Kunde gespeichert." : "Kunde erstellt."),
          ),
        );
        _loadCustomers();
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

  Future<void> _deleteCustomer(RecordModel customer) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Kunde löschen?"),
            content: Text(
              "Möchtest du ${customer.getStringValue('forename')} ${customer.getStringValue('surname')} wirklich löschen?",
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
      await pb.collection('trainer_customers').delete(customer.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kunde gelöscht.")),
        );
        _loadCustomers();
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
        title: const Text("Kundenstamm"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Kunden durchsuchen...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                      _filterCustomers();
                    },
                  ),
                ),
                Expanded(
                  child: filteredCustomers.isEmpty
                      ? Center(
                          child: Text(
                            searchQuery.isEmpty
                                ? "Keine Kunden vorhanden."
                                : "Keine Kunden gefunden.",
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = filteredCustomers[index];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(
                                  "${customer.getStringValue('forename')} ${customer.getStringValue('surname')}",
                                ),
                                subtitle: Text(
                                  customer.getStringValue('email'),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _editCustomer(customer),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _deleteCustomer(customer),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appFrontColor.value,
        onPressed: () => _editCustomer(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
