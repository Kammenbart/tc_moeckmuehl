import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class CourtTab extends StatefulWidget {
  final DateTime? initialDate; // 1. Diese Zeile hinzufügen
  const CourtTab({super.key, this.initialDate}); // 2. Konstruktor anpassen

  @override
  State<CourtTab> createState() => _CourtTabState();
}

class _CourtTabState extends State<CourtTab> {
  // Ändere DateTime _selectedDate = DateTime.now(); in:
  late DateTime _selectedDate; 
  List<RecordModel> courts = [];
  List<RecordModel> bookings = [];
  List<RecordModel> allUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate ?? DateTime.now();
    _refreshData();
  }

  Future<void> _refreshData() async {
  setState(() => isLoading = true);

  try {
    // 1. Plätze laden
    final fetchedCourts =
        await pb.collection('courts').getFullList(); // vorerst ohne sort
    // 2. alle User laden
    allUsers = await pb.collection('users').getFullList(); // vorerst ohne sort

    // 3. Buchungen laden
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
        .toUtc()
        .toIso8601String();
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59)
        .toUtc()
        .toIso8601String();

    final res = await pb.collection('bookings').getFullList(
      filter: 'start_time >= "$startOfDay" && start_time <= "$endOfDay"',
      expand: 'user,players,court',
    );

    setState(() {
      courts = fetchedCourts;
      bookings = res;
      isLoading = false;
    });
  } catch (e) {
    debugPrint("Fehler in _refreshData: $e");
    if (!mounted) return;
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Fehler beim Laden der Daten: $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  RecordModel? _getBooking(String courtId, DateTime cellTime) {
    for (var b in bookings) {
      if (b.getStringValue('court') != courtId) continue;

      final start = DateTime.parse(b.getStringValue('start_time')).toLocal();
      final end = DateTime.parse(b.getStringValue('end_time')).toLocal();

      if ((cellTime.isAtSameMomentAs(start) || cellTime.isAfter(start)) && cellTime.isBefore(end)) {
        return b;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = pb.authStore.model?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Platzbelegung"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                locale: const Locale('de', 'DE'),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _refreshData();
              }
            },
          )
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
            _refreshData();
          } else if (details.primaryVelocity! < 0) {
            setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
            _refreshData();
          }
        },
        child: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: appFrontColor.value,
                    child: Text(
                      DateFormat('EEEE, dd. MMMM yyyy', 'de_DE').format(_selectedDate),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    color: Colors.grey.shade200,
                    child: Row(
                      children: [
                        const SizedBox(width: 60), 
                        ...courts.map((c) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              c.getStringValue('surname'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: 28, 
                      itemBuilder: (context, index) {
                        final hour = 8 + (index ~/ 2);
                        final minute = (index % 2) * 30;
                        final cellTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
                        final timeString = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

                        return IntrinsicHeight(
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                                child: Text(timeString, style: const TextStyle(fontSize: 12)),
                              ),
                              ...courts.map((court) {
                                final booking = _getBooking(court.id, cellTime);
                                final isBooked = booking != null;

                                Color cellColor = Colors.white;
                                if (isBooked) {
                                  final isOwner = booking.getStringValue('user') == currentUserId;
                                  final playerIds = booking.getListValue('players');
                                  cellColor = (isOwner || playerIds.contains(currentUserId))
                                      ? ownBookingColor.value.withValues(alpha: 0.3)
                                      : otherBookingColor.value.withValues(alpha: 0.3);
                                }

                                final prevTime = cellTime.subtract(const Duration(minutes: 30));
                                final isSameAsAbove = isBooked && _getBooking(court.id, prevTime)?.id == booking.id;
                                final nextTime = cellTime.add(const Duration(minutes: 30));
                                final isSameAsBelow = isBooked && _getBooking(court.id, nextTime)?.id == booking.id;

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => isBooked ? _showBookingInfo(booking) : _showBookingDialog(court, cellTime),
                                    child: Container(
                                      height: 45,
                                      decoration: BoxDecoration(
                                        color: cellColor,
                                        border: Border(
                                          left: BorderSide(color: Colors.grey.shade300, width: 0.5),
                                          right: BorderSide(color: Colors.grey.shade300, width: 0.5),
                                          top: isSameAsAbove ? BorderSide.none : BorderSide(color: Colors.grey.shade400, width: 0.5),
                                          bottom: isSameAsBelow ? BorderSide.none : BorderSide(color: Colors.grey.shade400, width: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }), 
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  void _showBookingDialog(RecordModel court, DateTime startTime) {
    int selectedDuration = 60; 
    int repeatWeeks = 1;
    List<RecordModel> selectedPlayers = [];
    List<String> guestNames = [];
    final guestController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("${court.getStringValue('name')} buchen"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedDuration,
                        items: [30, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text("$m Min"))).toList(),
                        onChanged: (v) => setDialogState(() => selectedDuration = v!),
                        decoration: const InputDecoration(labelText: "Dauer"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: repeatWeeks,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Einzelbuchung")),
                    DropdownMenuItem(value: 4, child: Text("Abo: 1 Monat (4 Termine)")),
                    DropdownMenuItem(value: 12, child: Text("Abo: 3 Monate (12 Termine)")),
                    DropdownMenuItem(value: 26, child: Text("Abo: 1 Halbjahr (26 Termine)")),
                    DropdownMenuItem(value: 52, child: Text("Abo: 1 Jahr (52 Termine)")),
                  ],
                  onChanged: (v) => setDialogState(() => repeatWeeks = v!),
                  decoration: const InputDecoration(labelText: "Wiederholung / Abo"),
                ),
                const SizedBox(height: 15),
                const Text("Mitspieler:", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 5,
                  children: selectedPlayers.map((p) => Chip(
                    label: Text(p.getStringValue('surname')),
                    onDeleted: () => setDialogState(() => selectedPlayers.remove(p)),
                  )).toList(),
                ),
                TextButton.icon(
                  onPressed: () => _pickPlayer(
                    allUsers, 
                    selectedPlayers, 
                    (p) => setDialogState(() => selectedPlayers.add(p))
                  ),
                  icon: const Icon(Icons.person_add),
                  label: const Text("Mitglied hinzufügen"),
                ),
                TextField(
                  controller: guestController,
                  decoration: InputDecoration(
                    hintText: "Gast Name",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (guestController.text.isNotEmpty) {
                          setDialogState(() => guestNames.add(guestController.text));
                          guestController.clear();
                        }
                      },
                    ),
                  ),
                ),
                ...guestNames.map((g) => Text("Gast: $g")),
              ],
            ),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Abbrechen")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appFrontColor.value,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // 1. Lade-Indikator anzeigen
              showDialog(
                context: context, 
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator())
              );

              try {
                // 2. Buchungen durchführen
                for (int i = 0; i < repeatWeeks; i++) {
                  final currentStart = startTime.add(Duration(days: i * 7));
                  final currentEnd = currentStart.add(Duration(minutes: selectedDuration));
                  
                  await pb.collection('bookings').create(body: {
                    "user": pb.authStore.model!.id,
                    "court": court.id,
                    "start_time": currentStart.toUtc().toIso8601String(),
                    "end_time": currentEnd.toUtc().toIso8601String(),
                    "players": selectedPlayers.map((p) => p.id).toList(),
                    "guests": guestNames.join(", "),
                  });
                }

                // 3. Dialoge schließen und Grid aktualisieren
                Navigator.pop(context); // Lade-Dialog schließen
                Navigator.pop(context); // Buchungs-Dialog schließen
                _refreshData();

                // 4. Schönen Erfolgs-Dialog anzeigen
                if (mounted) {
                  _showSuccessDialog(
                    court.getStringValue('name'), 
                    startTime, 
                    repeatWeeks
                  );
                }

              } catch (e) {
                Navigator.pop(context); // Lade-Dialog schließen
                // Fehler anzeigen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Fehler: ${e.toString()}"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(repeatWeeks > 1 ? "Abo jetzt buchen" : "Jetzt buchen"),
          ),
        ],
        ),
      ),
    );
  }

void _showSuccessDialog(String courtName, DateTime date, int weeks) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
          const SizedBox(height: 16),
          const Text(
            "Buchung erfolgreich!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            weeks > 1 
              ? "Dein Abo für $courtName wurde erfolgreich für die nächsten $weeks Wochen angelegt."
              : "Deine Buchung für $courtName am ${DateFormat('dd.MM.yyyy').format(date)} wurde erfolgreich gespeichert.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 45),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Super!"),
          ),
        ],
      ),
    ),
  );
}

  void _pickPlayer(List<RecordModel> users, List<RecordModel> alreadySelected, Function(RecordModel) onPick) {
    String searchQuery = "";
    final currentUserId = pb.authStore.model?.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredUsers = users.where((u) {
            final isMe = u.id == currentUserId;
            final isAlreadySelected = alreadySelected.any((s) => s.id == u.id);
            final matchesSearch = u.getStringValue('surname').toLowerCase().contains(searchQuery.toLowerCase());
            return !isMe && !isAlreadySelected && matchesSearch;
          }).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Spieler suchen...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setSheetState(() => searchQuery = value),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(filteredUsers[i].getStringValue('surname')),
                      onTap: () {
                        onPick(filteredUsers[i]);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBookingInfo(RecordModel booking) {
    final currentUserId = pb.authStore.model?.id;
    final ownerList = booking.expand['user'];
    final ownerName = (ownerList != null && ownerList.isNotEmpty)
        ? ownerList[0].getStringValue('surname')
        : 'Unbekannt';
    final List<RecordModel> playerRecords = List<RecordModel>.from(booking.expand['players'] ?? []);
    final String formattedPlayerNames = playerRecords.map((p) => p.getStringValue('surname')).join(', ');
    final List<dynamic> playerIds = booking.getListValue('players');
    final bool canCancel = booking.getStringValue('user') == currentUserId || playerIds.contains(currentUserId);
    final String guestNames = booking.getStringValue('guests');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Buchungs-Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Gebucht von: $ownerName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            if (formattedPlayerNames.isNotEmpty) ...[
              const Text("Mitspieler (Mitglieder):", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(formattedPlayerNames),
              const SizedBox(height: 12),
            ],
            if (guestNames.isNotEmpty) ...[
              const Text("Gäste:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(guestNames),
            ],
          ],
        ),
        actions: [
          if (canCancel)
            TextButton(
              onPressed: () async {
                await pb.collection('bookings').delete(booking.id);
                Navigator.pop(context);
                _refreshData();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Stornieren"),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Schließen")),
        ],
      ),
    );
  }
}