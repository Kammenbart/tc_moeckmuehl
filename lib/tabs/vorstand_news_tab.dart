import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class VorstandNewsTab extends StatefulWidget {
  final int permission; // 1: nur eigene, 2: alle

  const VorstandNewsTab({super.key, required this.permission});

  @override
  State<VorstandNewsTab> createState() => _VorstandNewsTabState();
}

class _VorstandNewsTabState extends State<VorstandNewsTab> {
  List<RecordModel> news = [];
  bool isLoading = true;
  String searchQuery = "";
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final user = pb.authStore.record as RecordModel;
      final userId = user.id;
      final isAppAdmin = user.getBoolValue('auth_admin_app');
      
      // Load news based on permission
      String filter = '';
      if (widget.permission == 1 && !isAppAdmin) {
        // Only show own news for permission level 1
        filter = 'created_by = "$userId"';
      }
      // For permission 2 or app admin, show all news

      final result = await pb.collection('news').getFullList(
        sort: '-created',
        filter: filter.isNotEmpty ? filter : null,
      );

      if (mounted) {
        setState(() {
          news = result;
        });
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der News: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _filterNews() {
    // Implement search filtering
    setState(() {});
  }

  Future<void> _deleteNews(RecordModel newsItem) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("News löschen?"),
        content: const Text("Diese Aktion kann nicht rückgängig gemacht werden."),
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
    ) ?? false;

    if (!confirm) return;

    try {
      await pb.collection('news').delete(newsItem.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("News gelöscht.")),
        );
        _loadNews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editNews(RecordModel? newsItem) async {
    final isEdit = newsItem != null;
    final titleController = TextEditingController(
      text: isEdit ? newsItem.getStringValue('title') : '',
    );
    final contentController = TextEditingController(
      text: isEdit ? newsItem.getStringValue('content') : '',
    );

    final user = pb.authStore.record as RecordModel;
    final isCreator = isEdit && newsItem.getStringValue('created_by') == user.id;
    final canEdit = user.getBoolValue('auth_admin_app') ||
        widget.permission >= 2 ||
        (widget.permission == 1 && isCreator);

    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Keine Berechtigung zum Bearbeiten dieser News."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "News bearbeiten" : "News erstellen"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Titel"),
                maxLines: 1,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: "Inhalt"),
                maxLines: 5,
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
              await _saveNews(
                isEdit ? newsItem.id : null,
                titleController.text,
                contentController.text,
              );
            },
            child: Text(isEdit ? "Speichern" : "Erstellen"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNews(String? id, String title, String content) async {
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Titel und Inhalt erforderlich."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = pb.authStore.record as RecordModel;
      final body = {
        "title": title,
        "content": content,
        "created_by": user.id,
      };

      if (id != null) {
        // Update
        await pb.collection('news').update(id, body: body);
      } else {
        // Create
        await pb.collection('news').create(body: body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id != null ? "News gespeichert." : "News erstellt."),
          ),
        );
        _loadNews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.permission == 0) {
      return const Center(
        child: Text("Keine Berechtigung für die Nachrichtenverwaltung."),
      );
    }

    final filteredNews = news.where((n) {
      if (searchQuery.isEmpty) return true;
      final title = n.getStringValue('title').toLowerCase();
      final content = n.getStringValue('content').toLowerCase();
      return title.contains(searchQuery.toLowerCase()) ||
          content.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aktuelles (News)"),
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
                      hintText: "News durchsuchen...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                      _filterNews();
                    },
                  ),
                ),
                Expanded(
                  child: filteredNews.isEmpty
                      ? Center(
                          child: Text(
                            searchQuery.isEmpty
                                ? "Keine News vorhanden."
                                : "Keine News gefunden.",
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredNews.length,
                          itemBuilder: (context, index) {
                            final newsItem = filteredNews[index];
                            final created =
                                DateTime.parse(newsItem.created).toLocal();
                            final createdBy =
                                newsItem.getStringValue('created_by');
                            final currentUser =
                                (pb.authStore.record as RecordModel).id;
                            final isOwner = createdBy == currentUser;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                title: Text(newsItem.getStringValue('title')),
                                subtitle: Text(
                                  "Erstellt: ${DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(created)}",
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editNews(newsItem),
                                    ),
                                    if (widget.permission >= 2 || isOwner)
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _deleteNews(newsItem),
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(
                                        newsItem.getStringValue('title'),
                                      ),
                                      content: SingleChildScrollView(
                                        child: Text(
                                          newsItem.getStringValue('content'),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
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
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appFrontColor.value,
        onPressed: () => _editNews(null),
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
