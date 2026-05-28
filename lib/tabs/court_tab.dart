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
class _AboTerm {
  final DateTime start;
  final DateTime end;
  bool isAvailable;
  bool selected;

  _AboTerm({
    required this.start,
    required this.end,
    this.isAvailable = true,
    this.selected = true,
  });
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

  Future<List<RecordModel>> _getAboSeries(RecordModel booking) async {
  final aboId = booking.getStringValue('abo').isNotEmpty
      ? booking.getStringValue('abo')
      : booking.id;

  final res = await pb.collection('bookings').getFullList(
    filter: 'abo = "$aboId"',
    sort: 'start_time',
  );
  return res;
}

  Future<void> _deleteBookingList(List<RecordModel> list) async {
    if (list.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (final b in list) {
        await pb.collection('bookings').delete(b.id);
      }
      if (!mounted) return;
      Navigator.pop(context); // Lade-Dialog
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Lade-Dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fehler beim Löschen: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditBookingOrSeries(RecordModel booking) async {
    final bookingType = booking.getStringValue('booking_type');
    final isAbo = bookingType == 'abo';

    if (!isAbo) {
      // EINZELBUCHUNG: nur diese stornieren
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Buchung bearbeiten"),
          content: const Text("Möchtest du diese Buchung stornieren?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Abbrechen"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _deleteBookingList([booking]);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Stornieren"),
            ),
          ],
        ),
      );
      return;
    }

    // A B O: nur dieser Termin oder komplettes Abo
    final series = await _getAboSeries(booking);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Abo bearbeiten"),
        content: const Text(
          "Möchtest du nur diesen Termin oder das gesamte Abo stornieren?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Abbrechen"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteBookingList([booking]); // nur dieser Termin
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Nur diesen Termin"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteBookingList(series); // komplettes Abo
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Das gesamte Abo wurde storniert."),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Ganzes Abo"),
          ),
        ],
      ),
    );
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
                              c.getStringValue('name'),
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

                        final now = DateTime.now();
                        final isToday = now.year == _selectedDate.year &&
                            now.month == _selectedDate.month &&
                            now.day == _selectedDate.day;

                        // „Jetzt“-Zeile, wenn aktuelle Zeit in diesem 30-Minuten-Slot liegt
                        final isNowRow = isToday &&
                            now.isAfter(cellTime) &&
                            now.isBefore(cellTime.add(const Duration(minutes: 30)));

                        return IntrinsicHeight(
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: isNowRow
                                        ? const BorderSide(color: Colors.black, width: 2)
                                        : BorderSide.none,
                                    bottom: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: Text(timeString, style: const TextStyle(fontSize: 12)),
                              ),
                              ...courts.map((court) {
                                final booking = _getBooking(court.id, cellTime);
                                final isBooked = booking != null;

                                Color cellColor = Colors.white;
                                if (isBooked) {
                                  final eventType = booking.getStringValue('event_type'); // neues Feld in bookings (Select)
                                  if (eventType == 'Turnier' || eventType == 'Ligaspiel') {
                                    // Ligaspiel-/Turnierbuchung
                                    cellColor = eventBookingColor.value.withValues(alpha: 0.3);
                                  } else {
                                    // normale eigene/fremde Buchung
                                    final isOwner = booking.getStringValue('user') == currentUserId;
                                    final playerIds = booking.getListValue('players');
                                    cellColor = (isOwner || playerIds.contains(currentUserId))
                                        ? ownBookingColor.value.withValues(alpha: 0.3)
                                        : otherBookingColor.value.withValues(alpha: 0.3);
                                  }
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
                                          top: isNowRow
                                            ? const BorderSide(color: Colors.black, width: 2)
                                            : (isSameAsAbove
                                                ? BorderSide.none
                                                : BorderSide(color: Colors.grey.shade400, width: 0.5)),
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

  void _showBookingDialog(RecordModel court, DateTime cellTime) {
  // Start- und Endzeit
  TimeOfDay startTime = TimeOfDay(hour: cellTime.hour, minute: cellTime.minute);
  TimeOfDay endTime =
      TimeOfDay(hour: cellTime.add(const Duration(hours: 1)).hour, minute: cellTime.minute);

  // Buchungsart
  String bookingType = 'einzel'; // 'einzel' oder 'abo'
  DateTime? aboEndDate;

  // Rechte prüfen
  final userRecord = pb.authStore.record as RecordModel;
  final isAppAdmin = userRecord.getBoolValue('auth_admin_app');
  final permBoardBooking = userRecord.getIntValue('perm_board_booking');
  final canSetEventType = isAppAdmin || permBoardBooking >= 1;

  // Ligaspiel-/Turniertyp
  String eventType = ''; // '', 'Ligaspiel', 'Turnier'

  List<RecordModel> selectedPlayers = [];
  List<String> guestNames = [];
  final guestController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${court.getStringValue('name') ?? court.getStringValue('surname')} buchen"),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: "Info zu Mitspielern/Gästen",
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Mitspieler & Gäste eintragen"),
                    content: const SingleChildScrollView(
                      child: Text(
                        "Bitte trage nach Möglichkeit alle Spieler ein:\n\n"
                        "• Mitglieder über „Mitglied hinzufügen“ auswählen\n"
                        "• Gäste über das Gastfeld hinzufügen\n\n"
                        "So kann der Verein Auslastung, Beiträge und Statistiken korrekt erfassen.",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Verstanden"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Start / Ende
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Start"),
                      subtitle: Text(
                        "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} Uhr",
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setDialogState(() => startTime = picked);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Ende"),
                      subtitle: Text(
                        "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')} Uhr",
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (picked != null) {
                          setDialogState(() => endTime = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Buchungsart
              DropdownButtonFormField<String>(
                value: bookingType,
                decoration: const InputDecoration(
                  labelText: "Buchungsart",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'einzel', child: Text("Einzelbuchung")),
                  DropdownMenuItem(value: 'abo', child: Text("Abo")),
                ],
                onChanged: (v) {
                  setDialogState(() {
                    bookingType = v ?? 'einzel';
                    if (bookingType == 'abo' && aboEndDate == null) {
                      // Standard-Ende: letzter Wochentag im September
                      final year = cellTime.year;
                      final lastSeptDay = DateTime(year, 9, 30);
                      // auf denselben Wochentag wie cellTime bringen
                      DateTime temp = lastSeptDay;
                      while (temp.weekday != cellTime.weekday) {
                        temp = temp.subtract(const Duration(days: 1));
                      }
                      aboEndDate = temp;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),

              if (bookingType == 'abo')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Abo endet am"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aboEndDate != null
                            ? DateFormat('EEEE, dd.MM.yyyy', 'de_DE').format(aboEndDate!)
                            : "Bitte Datum wählen",
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Hinweis: Das Abo läuft inkl. dieses Datums.\n"
                        "Es werden alle Termine bis einschl. diesem Tag angelegt.",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: aboEndDate ?? cellTime,
                      firstDate: cellTime,
                      lastDate: DateTime(cellTime.year, 12, 31),
                      locale: const Locale('de', 'DE'),
                    );
                    if (picked != null) {
                      setDialogState(() => aboEndDate = picked);
                    }
                  },
                ),

              const SizedBox(height: 10),
              const Text("Mitspieler:", style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 5,
                children: selectedPlayers
                    .map(
                      (p) => Chip(
                        label: Text(p.getStringValue('surname')),
                        onDeleted: () => setDialogState(() => selectedPlayers.remove(p)),
                      ),
                    )
                    .toList(),
              ),
              TextButton.icon(
                onPressed: () => _pickPlayer(
                  allUsers,
                  selectedPlayers,
                  (p) => setDialogState(() => selectedPlayers.add(p)),
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
              const SizedBox(height: 10),
              // Liga-/Turnierbuchung (nur für Berechtigte)
              if (canSetEventType)
                DropdownButtonFormField<String>(
                  value: eventType.isEmpty ? null : eventType,
                  decoration: const InputDecoration(
                    labelText: "Ligaspiel / Turnier",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text("Keine")),
                    DropdownMenuItem(value: 'Ligaspiel', child: Text("Ligaspiel")),
                    DropdownMenuItem(value: 'Turnier', child: Text("Turnier")),
                  ],
                  onChanged: (v) => setDialogState(() => eventType = v ?? ''),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appFrontColor.value,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
  // Zeiten in DateTime umrechnen
  final start = DateTime(
    cellTime.year,
    cellTime.month,
    cellTime.day,
    startTime.hour,
    startTime.minute,
  );
  final end = DateTime(
    cellTime.year,
    cellTime.month,
    cellTime.day,
    endTime.hour,
    endTime.minute,
  );

  if (!end.isAfter(start)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Endzeit muss nach der Startzeit liegen."),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (bookingType == 'einzel') {
    // EINZELBUCHUNG: wie bisher, mit DB-Überschneidungsprüfung

    // 1. Überschneidung prüfen (mit Datenbank, aber Logik lokal)
    try {
      final dayStart = DateTime(cellTime.year, cellTime.month, cellTime.day)
          .toUtc()
          .toIso8601String();
      final dayEnd =
          DateTime(cellTime.year, cellTime.month, cellTime.day, 23, 59)
              .toUtc()
              .toIso8601String();

      final existing = await pb.collection('bookings').getFullList(
            filter:
                'court = "${court.id}" && start_time >= "$dayStart" && start_time <= "$dayEnd"',
          );

      final hasOverlap = existing.any((b) {
        final existingStart =
            DateTime.parse(b.getStringValue('start_time')).toLocal();
        final existingEnd =
            DateTime.parse(b.getStringValue('end_time')).toLocal();

        return start.isBefore(existingEnd) && end.isAfter(existingStart);
      });

      if (hasOverlap) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "In diesem Zeitraum ist der Platz bereits belegt.\nBitte andere Zeit wählen.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint("Fehler bei Überschneidungsprüfung: $e");
    }

    // 2. Buchung durchführen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await pb.collection('bookings').create(body: {
        "user": pb.authStore.record!.id,
        "court": court.id,
        "start_time": start.toUtc().toIso8601String(),
        "end_time": end.toUtc().toIso8601String(),
        "players": selectedPlayers.map((p) => p.id).toList(),
        "guests": guestNames.join(", "),
        "booking_type": bookingType,
        "event_type": eventType,
      });

      if (!mounted) return;
      Navigator.pop(context); // Lade-Dialog
      Navigator.pop(context); // Buchungs-Dialog
      _refreshData();
      _showSuccessDialog(
        court.getStringValue('name') ?? court.getStringValue('surname'),
        start,
        1,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Lade-Dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Fehler: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  } else {
    // A B O - B U C H U N G
    if (aboEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bitte ein Enddatum für das Abo wählen."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _showAboPreviewAndBook(
      court: court,
      firstStart: start,
      firstEnd: end,
      aboEndDate: aboEndDate!,
      selectedPlayers: selectedPlayers,
      guestNames: guestNames,
      eventType: eventType,
    );
  }
},

            child: const Text("Jetzt buchen"),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showAboPreviewAndBook({
  required RecordModel court,
  required DateTime firstStart,
  required DateTime firstEnd,
  required DateTime aboEndDate,
  required List<RecordModel> selectedPlayers,
  required List<String> guestNames,
  required String eventType,
}) async {
  // 1. Alle Abo-Termine erzeugen (wöchentlich gleicher Wochentag/Uhrzeit)
  final List<_AboTerm> terms = [];
  DateTime currentStart = firstStart;
  DateTime currentEnd = firstEnd;

  while (!currentStart.isAfter(aboEndDate)) {
    terms.add(_AboTerm(start: currentStart, end: currentEnd));
    currentStart = currentStart.add(const Duration(days: 7));
    currentEnd = currentEnd.add(const Duration(days: 7));
  }

  if (terms.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Keine Termine im gewählten Abo-Zeitraum."),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  // 2. Alle bestehenden Buchungen für diesen Zeitraum aus DB laden
  try {
    final overallStartIso = terms.first.start.toUtc().toIso8601String();
    final overallEndIso = terms.last.end.toUtc().toIso8601String();

    final existing = await pb.collection('bookings').getFullList(
          filter:
              'court = "${court.id}" && start_time < "$overallEndIso" && end_time > "$overallStartIso"',
        );

    // 3. Für jeden Termin prüfen, ob er frei ist
    for (final t in terms) {
      final hasOverlap = existing.any((b) {
        final existingStart =
            DateTime.parse(b.getStringValue('start_time')).toLocal();
        final existingEnd =
            DateTime.parse(b.getStringValue('end_time')).toLocal();
        return t.start.isBefore(existingEnd) && t.end.isAfter(existingStart);
      });
      t.isAvailable = !hasOverlap;
      t.selected = t.isAvailable; // Standard: alle freien Termine vorausgewählt
    }
  } catch (e) {
    debugPrint("Fehler bei Abo-Überschneidungsprüfung: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Fehler bei der Abo-Prüfung: $e"),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  // 4. Vorschau-Dialog mit Checkboxen anzeigen
  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text("Abo-Termine auswählen"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: terms.map((t) {
                    final label =
                        "${DateFormat('EEEE, dd.MM.yyyy', 'de_DE').format(t.start)} "
                        "${DateFormat('HH:mm', 'de_DE').format(t.start)} – "
                        "${DateFormat('HH:mm', 'de_DE').format(t.end)} Uhr";

                    if (!t.isAvailable) {
                      return ListTile(
                        title: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.red,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: const Text(
                          "Bereits belegt",
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    } else {
                      return CheckboxListTile(
                        value: t.selected,
                        onChanged: (v) =>
                            setState(() => t.selected = v ?? false),
                        title: Text(label),
                      );
                    }
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Abbrechen"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final toBook =
                      terms.where((t) => t.isAvailable && t.selected).toList();
                  if (toBook.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text("Keine Termine ausgewählt. Abo wird nicht gebucht."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx); // Vorschau-Dialog schließen

                  // 5. Buchungen für alle ausgewählten Termine anlegen
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    // Termine nach Datum sortieren, damit der erste Termin wirklich der erste in der Serie ist
                    final toBookSorted = [...toBook]
                      ..sort((a, b) => a.start.compareTo(b.start));

                    // 1. Ersten Termin ohne "abo" erstellen, um an die ID zu kommen
                    final firstTerm = toBookSorted.first;
                    final firstRecord = await pb.collection('bookings').create(body: {
                      "user": pb.authStore.record!.id,
                      "court": court.id,
                      "start_time": firstTerm.start.toUtc().toIso8601String(),
                      "end_time": firstTerm.end.toUtc().toIso8601String(),
                      "players": selectedPlayers.map((p) => p.id).toList(),
                      "guests": guestNames.join(", "),
                      "booking_type": "abo",
                      "event_type": eventType,
                      // "abo" kommt gleich in einem Update rein
                    });

                    final aboId = firstRecord.id;

                    // 2. Ersten Termin updaten: eigene ID ins "abo"-Feld schreiben
                    await pb.collection('bookings').update(
                      aboId,
                      body: {
                        "abo": aboId,
                      },
                    );

                    // 3. Alle weiteren Termine mit "abo": aboId anlegen
                    for (final t in toBookSorted.skip(1)) {
                      await pb.collection('bookings').create(body: {
                        "user": pb.authStore.record!.id,
                        "court": court.id,
                        "start_time": t.start.toUtc().toIso8601String(),
                        "end_time": t.end.toUtc().toIso8601String(),
                        "players": selectedPlayers.map((p) => p.id).toList(),
                        "guests": guestNames.join(", "),
                        "booking_type": "abo",
                        "event_type": eventType,
                        "abo": aboId, // hier direkt die ID des ersten Termins speichern
                      });
                    }

                    if (!mounted) return;
                    Navigator.pop(context); // Lade-Dialog schließen
                    Navigator.pop(context); // ursprünglichen Buchungsdialog schließen
                    _refreshData();
                    _showSuccessDialog(
                      court.getStringValue('name') ?? court.getStringValue('surname'),
                      firstStart,
                      toBookSorted.length,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context); // Lade-Dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Fehler beim Abo-Buchen: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text("Ausgewählte Termine buchen"),
              ),
            ],
          );
        },
      );
    },
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
    final String bookingType = booking.getStringValue('booking_type');
    final bool isAbo = bookingType == 'abo';

    // Nur der Besitzer darf "Bearbeiten" sehen
    final bool isOwner = booking.getStringValue('user') == currentUserId;
    final bool canEdit = isOwner;

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
          if (canEdit)
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Detaildialog schließen
                await _showEditBookingOrSeries(booking);
              },
              child: Text(isAbo ? "Abo bearbeiten" : "Buchung bearbeiten"),
            ),

          // Optional: Schnell-Storno wie bisher (kannst du auch weglassen,
          // wenn du alles über "Bearbeiten" abwickeln möchtest)
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
            child: const Text("Schließen"),
          ),
        ],
      ),
    );
  }
}