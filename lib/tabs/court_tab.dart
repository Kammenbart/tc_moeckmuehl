import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../main.dart';
class CourtTab extends StatefulWidget {
  const CourtTab({super.key});

  @override
  State<CourtTab> createState() => _CourtTabState();
}

class _CourtTabState extends State<CourtTab> {
  DateTime _selectedDate = DateTime.now();
  List<RecordModel> courts = [];
  List<RecordModel> bookings = [];
  List<RecordModel> allUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    
    // 1. Plätze laden und sortieren (damit Platz 1 immer links ist)
    final fetchedCourts = await pb.collection('courts').getFullList(sort: 'name');
    allUsers = await pb.collection('users').getFullList(sort: 'name');
    
    // 2. Buchungen für den gesamten Tag laden (mit User-Infos)
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).toUtc().toIso8601String();
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59).toUtc().toIso8601String();
    
    final res = await pb.collection('bookings').getFullList(
      filter: 'start_time >= "$startOfDay" && start_time <= "$endOfDay"',
      expand: 'user,players,court', 
    );
    
    setState(() {
      courts = fetchedCourts;
      bookings = res;
      isLoading = false;
    });
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
                firstDate: DateTime.now().subtract(const Duration(days: 7)),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _refreshData();
              }
            },
          )
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 1. Datumsanzeige
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

              // 2. Kopfzeile mit Platznamen
              Container(
                color: Colors.grey.shade200,
                child: Row(
                  children: [
                    const SizedBox(width: 60), 
                    ...courts.map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          c.getStringValue('name'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )),
                  ],
                ),
              ),

              // 3. Scrollbares Grid
              Expanded(
                child: ListView.builder(
                  itemCount: 28, // 8:00 bis 22:00 Uhr
                  itemBuilder: (context, index) {
                    final hour = 8 + (index ~/ 2);
                    final minute = (index % 2) * 30;
                    
                    final cellTime = DateTime(
                      _selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute
                    );
                    
                    final timeString = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

                    return IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                            ),
                            child: Text(timeString, style: const TextStyle(fontSize: 12)),
                          ),
                          ...courts.map((court) {
                            final booking = _getBooking(court.id, cellTime);
                            final isBooked = booking != null;

                            // --- NEU: FARBLOGIK ---
                            Color cellColor = Colors.white;
                            if (isBooked) {
                              final isOwner = booking.getStringValue('user') == currentUserId;
                              final playerIds = booking.getListValue('players');
                              final isPlayer = playerIds.contains(currentUserId);

                              if (isOwner || isPlayer) {
                                // Eigene Buchung (transparent blau)
                                cellColor = ownBookingColor.value.withOpacity(0.3);
                              } else {
                                // Fremde Buchung (transparent rot)
                                cellColor = otherBookingColor.value.withOpacity(0.3);
                              }
                            }

                            final prevTime = cellTime.subtract(const Duration(minutes: 30));
                            final bookingAbove = _getBooking(court.id, prevTime);
                            final isSameAsAbove = isBooked && bookingAbove?.id == booking.id;

                            final nextTime = cellTime.add(const Duration(minutes: 30));
                            final bookingBelow = _getBooking(court.id, nextTime);
                            final isSameAsBelow = isBooked && bookingBelow?.id == booking.id;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => isBooked ? _showBookingInfo(booking) : _showBookingDialog(court, cellTime),
                                child: Container(
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: cellColor, // Hier wird die neue Farbe angewandt
                                    border: Border(
                                      left: BorderSide(color: Colors.grey.shade300, width: 0.5),
                                      right: BorderSide(color: Colors.grey.shade300, width: 0.5),
                                      top: isSameAsAbove 
                                          ? BorderSide.none 
                                          : BorderSide(color: Colors.grey.shade400, width: 0.5),
                                      bottom: isSameAsBelow 
                                          ? BorderSide.none 
                                          : BorderSide(color: Colors.grey.shade400, width: 0.5),
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
    );
  }

  // --- DIALOG: NEUE BUCHUNG ---
  void _showBookingDialog(RecordModel court, DateTime startTime) {
    int selectedDuration = 60; 
    int repeatWeeks = 1; // NEU: Variable für das Abo (Standard = 1 = Einzelbuchung)
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
                // --- NEU: ABO-AUSWAHL ---
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
                    label: Text(p.getStringValue('name')),
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
            ElevatedButton(
              onPressed: () async {
                // Lade-Indikator anzeigen, falls ein langes Abo gebucht wird
                showDialog(
                  context: context, 
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator())
                );

                try {
                  // --- NEU: SCHLEIFE FÜR ABO-BUCHUNGEN ---
                  for (int i = 0; i < repeatWeeks; i++) {
                    // Startzeit um i Wochen verschieben
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
                } finally {
                  // Lade-Dialog schließen
                  Navigator.pop(context);
                  // Buchungs-Dialog schließen
                  Navigator.pop(context);
                  // Grid neu laden
                  _refreshData();
                }
              },
              child: Text(repeatWeeks > 1 ? "Abo Buchen" : "Buchen"),
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
            final matchesSearch = u.getStringValue('name').toLowerCase().contains(searchQuery.toLowerCase());
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
                  onChanged: (value) {
                    setSheetState(() => searchQuery = value);
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(filteredUsers[i].getStringValue('name')),
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

  // --- DIALOG: INFO WER GEBUCHT HAT ---
  void _showBookingInfo(RecordModel booking) {
    final currentUserId = pb.authStore.model?.id;

    final ownerList = booking.expand['user'];
    final ownerName = (ownerList != null && ownerList.isNotEmpty)
        ? ownerList[0].getStringValue('name')
        : 'Unbekannt';

    final List<RecordModel> playerRecords = List<RecordModel>.from(booking.expand['players'] ?? []);
    final String formattedPlayerNames = playerRecords.map((p) => p.getStringValue('name')).join(', ');

    final List<dynamic> playerIds = booking.getListValue('players');
    final bool isOwner = booking.getStringValue('user') == currentUserId;
    final bool isPlayer = playerIds.contains(currentUserId);
    
    final bool canCancel = isOwner || isPlayer;

    final String guestNames = booking.getStringValue('guests');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Buchungs-Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Gebucht von: $ownerName", 
                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            const SizedBox(height: 5),
            
            if (formattedPlayerNames.isNotEmpty) ...[
              const Text("Mitspieler (Mitglieder):", 
                         style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(formattedPlayerNames),
              const SizedBox(height: 12),
            ],
            
            if (guestNames.isNotEmpty) ...[
              const Text("Gäste:", 
                         style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(guestNames),
            ],
            
            if (formattedPlayerNames.isEmpty && guestNames.isEmpty)
              const Text("Keine weiteren Mitspieler eingetragen.", 
                         style: TextStyle(fontStyle: FontStyle.italic)),
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
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Schließen")
          ),
        ],
      ),
    );
  }
}