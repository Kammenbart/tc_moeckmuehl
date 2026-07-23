import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../main.dart';
import 'trainer_invoices_tab.dart';
import 'trainer_reminders_tab.dart';
import 'trainer_services_tab.dart';

Future<List<RecordModel>> loadTrainerGroupsSafe(String userId) async {
  final attempts = <String?>[
    'trainer = "$userId"',
    'trainer ~ "$userId"',
    null,
  ];

  for (final filter in attempts) {
    try {
      final records = await pb.collection('trainer_groups').getFullList(filter: filter);
      final filtered = filter == null
          ? records.where(_recordHasAnyTrainer).toList()
          : records.where((record) => _recordHasTrainerId(record, userId)).toList();

      filtered.sort((a, b) => _groupSortKey(a).compareTo(_groupSortKey(b)));
      return filtered;
    } on ClientException catch (e) {
      debugPrint('trainer_groups Versuch fehlgeschlagen (filter: $filter): $e');
      continue;
    } catch (e) {
      debugPrint('trainer_groups unerwarteter Fehler (filter: $filter): $e');
      continue;
    }
  }

  return const [];
}

List<String> _extractIdsFromRaw(dynamic raw) {
  final values = <String>[];
  if (raw is String) {
    final value = raw.trim();
    if (value.isNotEmpty) values.add(value);
    return values;
  }
  if (raw is List) {
    for (final entry in raw) {
      values.addAll(_extractIdsFromRaw(entry));
    }
    return values;
  }
  if (raw is Map) {
    final value = (raw['id'] ?? raw['trainer'] ?? raw['user'] ?? raw['member'] ?? raw['customer'] ?? '').toString().trim();
    if (value.isNotEmpty) values.add(value);
  }
  return values;
}

bool _recordHasTrainerId(RecordModel record, String trainerId) {
  return _extractIdsFromRaw(record.toJson()['trainer']).contains(trainerId);
}

bool _recordHasAnyTrainer(RecordModel record) {
  return _extractIdsFromRaw(record.toJson()['trainer']).isNotEmpty;
}

DateTime? _parsePortableDate(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  try {
    return DateTime.parse(text).toLocal();
  } catch (_) {
    return null;
  }
}

String _groupSortKey(RecordModel record) {
  final json = record.toJson();
  final start = _parsePortableDate(json['start']) ?? _parsePortableDate(json['start_date']);
  final created = _parsePortableDate(json['created']);
  final date = start ?? created;
  return date?.toIso8601String() ?? record.id;
}

class TrainingSessionSuggestion {
  final String key;
  final String title;
  final String subtitle;
  final DateTime startAt;
  final DateTime endAt;
  final List<RecordModel> participants;
  final bool isManual;
  final RecordModel? sourceGroup;

  TrainingSessionSuggestion({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.startAt,
    required this.endAt,
    required this.participants,
    required this.isManual,
    this.sourceGroup,
  });
}

class _ParticipantDraft {
  final RecordModel user;
  final String fullName;
  String presence;
  String service;
  String duration;
  String cost;
  String share;
  final TextEditingController serviceController;
  final TextEditingController durationController;
  final TextEditingController costController;
  final TextEditingController shareController;

  _ParticipantDraft({
    required this.user,
    required this.fullName,
    required this.presence,
    required this.service,
    required this.duration,
    required this.cost,
    required this.share,
  })  : serviceController = TextEditingController(text: service),
        durationController = TextEditingController(text: duration),
        costController = TextEditingController(text: cost),
        shareController = TextEditingController(text: share);
}

double parseShareValue(String raw) {
  final normalized = raw.replaceAll('%', '').replaceAll(',', '.').trim();
  final value = double.tryParse(normalized) ?? 0.0;
  if (value <= 1) return value;
  return value / 100;
}

String buildAutoShareText(int totalPlayers) {
  if (totalPlayers <= 0) return '0%';
  return '${(100 / totalPlayers).toStringAsFixed(0)}%';
}

void applyAutoParticipantShares(List<_ParticipantDraft> drafts) {
  final autoShareText = buildAutoShareText(drafts.length);
  for (final draft in drafts) {
    draft.shareController.text = autoShareText;
  }
}

String formatCurrencyInput(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

Map<String, String> buildManualTemplateDefaults(RecordModel? sourceGroup, bool training) {
  final groupName = sourceGroup?.getStringValue('name').trim() ?? '';
  final service = groupName.isNotEmpty ? groupName : (training ? 'Training' : 'Sonstiges');
  final duration = sourceGroup?.getDoubleValue('duration')?.toString() ?? '';
  final cost = sourceGroup?.getDoubleValue('cost')?.toString() ?? '0';
  final hallCost = sourceGroup?.getIntValue('cost_center').toString() ?? '0';
  return {
    'service': service,
    'duration': duration,
    'cost': cost,
    'hallCost': hallCost,
  };
}

String formatDateForInput(DateTime value) {
  try {
    return DateFormat('dd.MM.yyyy', 'de_DE').format(value);
  } catch (_) {
    return DateFormat('dd.MM.yyyy').format(value);
  }
}

String formatTimeForInput(DateTime value) {
  try {
    return DateFormat('HH:mm', 'de_DE').format(value);
  } catch (_) {
    return DateFormat('HH:mm').format(value);
  }
}

class MonthlyRevenuePoint {
  final String label;
  final double amount;

  const MonthlyRevenuePoint({required this.label, required this.amount});
}

class PortalBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const PortalBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            appFrontColor.value,
            appFrontColor.value.withValues(alpha: 0.78),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: appFrontColor.value.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<DateTime> buildTemplateOccurrences({
  required DateTime windowStart,
  required DateTime windowEnd,
  required TimeOfDay startTime,
  required TimeOfDay endTime,
  required String recurrence,
}) {
  final intervalDays = recurrence == '2 weekly' ? 14 : 7;
  final dates = <DateTime>[];
  var cursor = DateTime(
    windowStart.year,
    windowStart.month,
    windowStart.day,
    startTime.hour,
    startTime.minute,
  );

  while (cursor.isBefore(windowStart)) {
    cursor = cursor.add(Duration(days: intervalDays));
  }

  while (!cursor.isAfter(windowEnd)) {
    dates.add(cursor);
    cursor = cursor.add(Duration(days: intervalDays));
  }

  return dates;
}

List<RecordModel> _resolveSuggestionParticipants(
  RecordModel group,
  List<RecordModel> fallbackParticipants,
) {
  final rawMembers = group.getListValue('member');
  final memberIds = rawMembers
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toSet();

  if (memberIds.isEmpty) return fallbackParticipants;

  final matched = fallbackParticipants.where((user) => memberIds.contains(user.id)).toList();
  return matched.isNotEmpty ? matched : fallbackParticipants;
}

List<TrainingSessionSuggestion> buildTrainingSuggestions(
  List<RecordModel> groups, {
  List<RecordModel> fallbackParticipants = const [],
  int horizonDays = 42,
  DateTime? now,
}) {
  final suggestions = <TrainingSessionSuggestion>[];
  final referenceNow = now ?? DateTime.now();
  final horizonStart = referenceNow.subtract(Duration(days: horizonDays));

  for (final group in groups) {
    final startDate = _parsePortableDate(group.toJson()['start']) ?? _parsePortableDate(group.toJson()['start_date']);
    if (startDate == null) continue;

    final stateDate = _parsePortableDate(group.toJson()['state']);
    final recurrence = group.getStringValue('interval').trim();
    final cycleDays = recurrence == '2 weekly' ? 14 : 7;
    var cursor = startDate;
    TrainingSessionSuggestion? latestCandidate;

    while (!cursor.isAfter(referenceNow) && cursor.isAfter(horizonStart.subtract(const Duration(days: 1)))) {
      final isAfterState = stateDate == null || cursor.isAfter(stateDate);
      if (isAfterState && (cursor.isBefore(referenceNow) || cursor.isAtSameMomentAs(referenceNow))) {
        latestCandidate = TrainingSessionSuggestion(
          key: '${group.id}-${cursor.toIso8601String()}',
          title: group.getStringValue('name').isEmpty
              ? 'Trainingsvorschlag'
              : group.getStringValue('name'),
          subtitle: group.getStringValue('level').isEmpty
              ? 'Training'
              : group.getStringValue('level'),
          startAt: cursor,
          endAt: cursor.add(const Duration(hours: 1, minutes: 30)),
          participants: _resolveSuggestionParticipants(group, fallbackParticipants),
          isManual: false,
          sourceGroup: group,
        );
      }
      cursor = cursor.add(Duration(days: cycleDays));
    }

    if (latestCandidate != null) {
      suggestions.add(latestCandidate);
    }
  }

  suggestions.sort((a, b) => a.startAt.compareTo(b.startAt));
  return suggestions;
}

List<MonthlyRevenuePoint> buildRevenuePoints(
  List<RecordModel> invoices, {
  int monthsBack = 6,
}) {
  final now = DateTime.now();
  final buckets = <String, double>{};
  final labels = <String>[];

  for (var offset = monthsBack - 1; offset >= 0; offset--) {
    final month = DateTime(now.year, now.month - offset, 1);
    final key = '${month.year}-${month.month}';
    buckets[key] = 0;
    labels.add(DateFormat('MMM', 'de_DE').format(month));
  }

  for (final invoice in invoices) {
    final rawDate = invoice.getStringValue('submission_date').trim().isNotEmpty
        ? invoice.getStringValue('submission_date')
        : invoice.getStringValue('created');
    final parsed = DateTime.tryParse(rawDate)?.toLocal();
    if (parsed == null) continue;

    final key = '${parsed.year}-${parsed.month}';
    if (!buckets.containsKey(key)) continue;
    buckets[key] = (buckets[key] ?? 0) + invoice.getDoubleValue('amount');
  }

  return buckets.entries.map((entry) {
    final index = labels.length - buckets.keys.toList().indexOf(entry.key) - 1;
    return MonthlyRevenuePoint(
      label: labels[index.clamp(0, labels.length - 1)],
      amount: entry.value,
    );
  }).toList();
}

class TrainerDashboardTab extends StatefulWidget {
  const TrainerDashboardTab({super.key});

  @override
  State<TrainerDashboardTab> createState() => _TrainerDashboardTabState();
}

class _TrainerDashboardTabState extends State<TrainerDashboardTab> {
  bool _loading = true;
  List<RecordModel> _groups = [];
  List<RecordModel> _invoices = [];
  List<RecordModel> _allUsers = [];
  List<RecordModel> _trainingUsers = [];
  final Map<String, Map<String, String?>> _attendance = {};
  final List<TrainingSessionSuggestion> _manualSuggestions = [];
  final Set<String> _completedSuggestionKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final user = pb.authStore.record as RecordModel;
      final groups = await loadTrainerGroupsSafe(user.id);
      final invoices = await pb.collection('invoices').getFullList(
            filter: 'submitted_by = "${user.id}"',
            sort: '-created',
          );
      final allUsers = await pb.collection('users').getFullList(
            sort: 'surname,forename',
          );
      final filteredTrainingUsers = allUsers.where((user) => user.getBoolValue('training')).toList();

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _invoices = invoices;
        _allUsers = allUsers;
        _trainingUsers = filteredTrainingUsers.isNotEmpty ? filteredTrainingUsers : allUsers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dashboard konnte nicht geladen werden: $e')),
      );
    }
  }

  List<TrainingSessionSuggestion> get _suggestions {
    final allSuggestions = [
      ..._manualSuggestions,
      ...buildTrainingSuggestions(
        _groups,
        fallbackParticipants: _allUsers,
      ),
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));

    return allSuggestions.where((suggestion) => !_completedSuggestionKeys.contains(suggestion.key)).toList();
  }

  Future<void> _persistSuggestionDecision(TrainingSessionSuggestion suggestion) async {
    final sourceGroup = suggestion.sourceGroup;
    if (sourceGroup == null) return;

    await pb.collection('trainer_groups').update(sourceGroup.id, body: {
      'state': suggestion.startAt.toIso8601String(),
    });
  }

  Future<void> _decideSuggestion(TrainingSessionSuggestion suggestion, bool accepted) async {
    if (accepted) {
      final confirmed = await _openAttendanceSheet(suggestion);
      if (!confirmed) return;
    } else {
      try {
        await _persistSuggestionDecision(suggestion);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ablehnung konnte nicht gespeichert werden: $e'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    try {
      await _persistSuggestionDecision(suggestion);
      if (!mounted) return;
      setState(() {
        _completedSuggestionKeys.add(suggestion.key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accepted ? 'Training angenommen und Leistungen gespeichert.' : 'Trainingsvorschlag abgelehnt.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern der Entscheidung: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _openAttendanceSheet(TrainingSessionSuggestion suggestion) async {
    final participants = suggestion.participants.isNotEmpty ? suggestion.participants : _trainingUsers;
    final initialService = suggestion.title.trim().isNotEmpty ? suggestion.title.trim() : 'Training';
    final initialDuration = suggestion.sourceGroup?.getDoubleValue('duration')?.toString() ?? '1.5';
    final initialCost = suggestion.sourceGroup?.getDoubleValue('cost')?.toString() ?? '0';
    final initialHallCost = suggestion.sourceGroup?.getIntValue('cost_center').toString() ?? '0';
    final initialShare = '100';
    final drafts = <_ParticipantDraft>[
      for (final participant in participants)
        _ParticipantDraft(
          user: participant,
          fullName: '${participant.getStringValue('forename')} ${participant.getStringValue('surname')}'.trim(),
          presence: 'present',
          service: initialService,
          duration: initialDuration,
          cost: initialCost,
          share: initialShare,
        ),
    ];
    applyAutoParticipantShares(drafts);

    final serviceController = TextEditingController(text: initialService);
    final durationController = TextEditingController(text: initialDuration);
    final costController = TextEditingController(text: formatCurrencyInput(double.tryParse(initialCost) ?? 0.0));
    final hallCostController = TextEditingController(text: formatCurrencyInput(double.tryParse(initialHallCost) ?? 0.0));
    final costSuffix = ' €';
    final hallCostSuffix = ' €';
    final shareController = TextEditingController(text: initialShare);
    final dateController = TextEditingController(text: formatDateForInput(suggestion.startAt));
    final timeController = TextEditingController(text: formatTimeForInput(suggestion.startAt));
    var selectedDateTime = suggestion.startAt;

    if (!mounted) return false;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            minChildSize: 0.6,
            maxChildSize: 0.98,
            builder: (context, scrollController) {
              return Material(
                color: Theme.of(context).canvasColor,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 0,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: serviceController,
                                          decoration: const InputDecoration(labelText: 'Leistung'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: durationController,
                                          decoration: const InputDecoration(labelText: 'Dauer (h)'),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: costController,
                                          decoration: InputDecoration(labelText: 'Kosten', suffixText: costSuffix),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (value) {
                                            final sanitized = value.replaceAll(costSuffix, '').replaceAll('.', '').replaceAll(',', '.').trim();
                                            final parsed = double.tryParse(sanitized);
                                            if (parsed == null) return;
                                            final formatted = formatCurrencyInput(parsed);
                                            if (costController.text != formatted) {
                                              costController.value = TextEditingValue(
                                                text: formatted,
                                                selection: TextSelection.collapsed(offset: formatted.length - 2),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: hallCostController,
                                          decoration: InputDecoration(labelText: 'Hallenkosten', suffixText: hallCostSuffix),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (value) {
                                            final sanitized = value.replaceAll(hallCostSuffix, '').replaceAll('.', '').replaceAll(',', '.').trim();
                                            final parsed = double.tryParse(sanitized);
                                            if (parsed == null) return;
                                            final formatted = formatCurrencyInput(parsed);
                                            if (hallCostController.text != formatted) {
                                              hallCostController.value = TextEditingValue(
                                                text: formatted,
                                                selection: TextSelection.collapsed(offset: formatted.length - 2),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: dateController,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Datum',
                                            suffixIcon: Icon(Icons.calendar_today_outlined),
                                          ),
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate: selectedDateTime,
                                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                                            );
                                            if (date == null) return;
                                            final updated = DateTime(date.year, date.month, date.day, selectedDateTime.hour, selectedDateTime.minute);
                                            setSheetState(() {
                                              selectedDateTime = updated;
                                              dateController.text = formatDateForInput(selectedDateTime);
                                              timeController.text = formatTimeForInput(selectedDateTime);
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: timeController,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Uhrzeit',
                                            suffixIcon: Icon(Icons.access_time),
                                          ),
                                          onTap: () async {
                                            final time = await showTimePicker(
                                              context: context,
                                              initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                                            );
                                            if (time == null) return;
                                            final updated = DateTime(selectedDateTime.year, selectedDateTime.month, selectedDateTime.day, time.hour, time.minute);
                                            setSheetState(() {
                                              selectedDateTime = updated;
                                              dateController.text = formatDateForInput(selectedDateTime);
                                              timeController.text = formatTimeForInput(selectedDateTime);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    showModalBottomSheet<void>(
                                      context: ctx,
                                      builder: (pickerContext) => SizedBox(
                                        height: 420,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                              child: Text(
                                                'Spieler auswählen',
                                                style: Theme.of(context).textTheme.titleMedium,
                                              ),
                                            ),
                                            Expanded(
                                              child: ListView(
                                                children: _allUsers
                                                    .where((user) => !drafts.any((draft) => draft.user.id == user.id))
                                                    .map((user) {
                                                      final fullName = '${user.getStringValue('forename')} ${user.getStringValue('surname')}'.trim();
                                                      return ListTile(
                                                        title: Text(fullName.isEmpty ? user.getStringValue('email') : fullName),
                                                        subtitle: Text(user.getStringValue('email')),
                                                        onTap: () {
                                                          setSheetState(() {
                                                            drafts.add(_ParticipantDraft(
                                                              user: user,
                                                              fullName: fullName,
                                                              presence: 'present',
                                                              service: serviceController.text.trim().isEmpty ? 'Training' : serviceController.text.trim(),
                                                              duration: durationController.text.trim().isEmpty ? '1.5' : durationController.text.trim(),
                                                              cost: costController.text.trim().isEmpty ? '0' : costController.text.trim(),
                                                              share: shareController.text.trim().isEmpty ? '100' : shareController.text.trim(),
                                                            ));
                                                            applyAutoParticipantShares(drafts);
                                                          });
                                                          Navigator.pop(pickerContext);
                                                        },
                                                      );
                                                    })
                                                    .toList(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Spieler hinzufügen'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: drafts.length,
                        itemBuilder: (context, index) {
                          final draft = drafts[index];
                          final totalPlayers = drafts.length;
                          final autoSharePercent = buildAutoShareText(totalPlayers);
                          if (draft.shareController.text.trim().isEmpty || draft.shareController.text == '100' || draft.shareController.text == '100%') {
                            draft.shareController.text = autoSharePercent;
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          draft.fullName.isEmpty ? draft.user.getStringValue('email') : draft.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => setSheetState(() {
                                          drafts.removeAt(index);
                                          applyAutoParticipantShares(drafts);
                                        }),
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Anwesend', style: TextStyle(fontSize: 13)),
                                          value: draft.presence == 'present',
                                          onChanged: (value) {
                                            setSheetState(() => draft.presence = value == true ? 'present' : 'absent');
                                          },
                                          controlAffinity: ListTileControlAffinity.leading,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  TextField(
                                    controller: draft.shareController,
                                    decoration: InputDecoration(
                                      labelText: 'Anteil (%)',
                                      hintText: autoSharePercent,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Abbrechen'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  final user = pb.authStore.record as RecordModel;
                                  for (final draft in drafts) {
                                    final duration = double.tryParse(durationController.text.replaceAll(',', '.')) ?? 0.0;
                                    final cost = double.tryParse(costController.text.replaceAll('€', '').replaceAll('.', '').replaceAll(',', '.').trim()) ?? 0.0;
                                    final hallCost = double.tryParse(hallCostController.text.replaceAll('€', '').replaceAll('.', '').replaceAll(',', '.').trim()) ?? 0.0;
                                    final share = parseShareValue(draft.shareController.text);
                                    final body = <String, dynamic>{
                                      'service': serviceController.text.trim().isEmpty ? 'Training' : serviceController.text.trim(),
                                      'duration': duration,
                                      'cost': cost,
                                      'share': share,
                                      'date': selectedDateTime.toIso8601String(),
                                      'customer': draft.user.id,
                                      'presence': draft.presence,
                                      'trainer': user.id,
                                      'hall_cost': hallCost,
                                    };
                                    try {
                                      await pb.collection('trainer_services').create(body: body);
                                    } catch (e) {
                                      final fallbackBody = Map<String, dynamic>.from(body)..remove('hall_cost');
                                      await pb.collection('trainer_services').create(body: fallbackBody);
                                    }
                                  }
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx, true);
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Fehler beim Speichern der Leistungen: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: const Text('Bestätigen'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    return confirmed ?? false;
  }

  Future<RecordModel?> _pickManualTemplateGroup() async {
    if (_groups.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Gruppen vorhanden, die als Vorlage dienen können.')),
      );
      return null;
    }

    return showModalBottomSheet<RecordModel?>(
      context: context,
      builder: (ctx) => SizedBox(
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Gruppe als Vorlage wählen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView(
                children: _groups.map((group) {
                  final label = group.getStringValue('name').trim().isEmpty ? 'Unbenannte Gruppe' : group.getStringValue('name');
                  return ListTile(
                    title: Text(label),
                    subtitle: Text(group.getStringValue('level').trim().isEmpty ? 'Vorlage' : group.getStringValue('level')),
                    onTap: () => Navigator.pop(ctx, group),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManualDialog({required bool training, RecordModel? sourceGroup}) async {
    final templateDefaults = buildManualTemplateDefaults(sourceGroup, training);
    final initialService = templateDefaults['service'] ?? (training ? 'Training' : 'Sonstiges');
    final initialDuration = templateDefaults['duration'] ?? '';
    final initialCost = templateDefaults['cost'] ?? '0';
    final initialHallCost = templateDefaults['hallCost'] ?? '0';
    final initialParticipants = sourceGroup != null ? _resolveSuggestionParticipants(sourceGroup, _trainingUsers) : <RecordModel>[];

    final serviceController = TextEditingController(text: initialService);
    final durationController = TextEditingController(text: initialDuration);
    final costController = TextEditingController(text: formatCurrencyInput(double.tryParse(initialCost) ?? 0));
    final hallCostController = TextEditingController(text: formatCurrencyInput(double.tryParse(initialHallCost) ?? 0));
    final drafts = <_ParticipantDraft>[
      for (final participant in initialParticipants)
        _ParticipantDraft(
          user: participant,
          fullName: '${participant.getStringValue('forename')} ${participant.getStringValue('surname')}'.trim(),
          presence: 'present',
          service: initialService,
          duration: initialDuration,
          cost: initialCost,
          share: '100',
        ),
    ];
    final dateController = TextEditingController(text: formatDateForInput(DateTime.now()));
    final timeController = TextEditingController(text: formatTimeForInput(DateTime.now()));
    var selectedDateTime = DateTime.now();

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            minChildSize: 0.6,
            maxChildSize: 0.98,
            builder: (context, scrollController) {
              return Material(
                color: Theme.of(context).canvasColor,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 0,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: serviceController,
                                          decoration: const InputDecoration(labelText: 'Leistung'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: durationController,
                                          decoration: const InputDecoration(labelText: 'Dauer (h)'),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: costController,
                                          decoration: InputDecoration(labelText: 'Kosten', suffixText: '€'),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (value) {
                                            final sanitized = value.replaceAll('€', '').replaceAll('.', '').replaceAll(',', '.').trim();
                                            final parsed = double.tryParse(sanitized);
                                            if (parsed == null) return;
                                            final formatted = formatCurrencyInput(parsed);
                                            if (costController.text != formatted) {
                                              costController.value = TextEditingValue(
                                                text: formatted,
                                                selection: TextSelection.collapsed(offset: formatted.length),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: hallCostController,
                                          decoration: InputDecoration(labelText: 'Hallenkosten', suffixText: '€'),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (value) {
                                            final sanitized = value.replaceAll('€', '').replaceAll('.', '').replaceAll(',', '.').trim();
                                            final parsed = double.tryParse(sanitized);
                                            if (parsed == null) return;
                                            final formatted = formatCurrencyInput(parsed);
                                            if (hallCostController.text != formatted) {
                                              hallCostController.value = TextEditingValue(
                                                text: formatted,
                                                selection: TextSelection.collapsed(offset: formatted.length),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: dateController,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Datum',
                                            suffixIcon: Icon(Icons.calendar_today_outlined),
                                          ),
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate: selectedDateTime,
                                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                                            );
                                            if (date == null) return;
                                            final updated = DateTime(date.year, date.month, date.day, selectedDateTime.hour, selectedDateTime.minute);
                                            setSheetState(() {
                                              selectedDateTime = updated;
                                              dateController.text = formatDateForInput(selectedDateTime);
                                              timeController.text = formatTimeForInput(selectedDateTime);
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: timeController,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Uhrzeit',
                                            suffixIcon: Icon(Icons.access_time),
                                          ),
                                          onTap: () async {
                                            final time = await showTimePicker(
                                              context: context,
                                              initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                                            );
                                            if (time == null) return;
                                            final updated = DateTime(selectedDateTime.year, selectedDateTime.month, selectedDateTime.day, time.hour, time.minute);
                                            setSheetState(() {
                                              selectedDateTime = updated;
                                              dateController.text = formatDateForInput(selectedDateTime);
                                              timeController.text = formatTimeForInput(selectedDateTime);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    showModalBottomSheet<void>(
                                      context: ctx,
                                      builder: (pickerContext) => SizedBox(
                                        height: 420,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                              child: Text(
                                                'Spieler auswählen',
                                                style: Theme.of(context).textTheme.titleMedium,
                                              ),
                                            ),
                                            Expanded(
                                              child: ListView(
                                                children: _allUsers
                                                    .where((user) => !drafts.any((draft) => draft.user.id == user.id))
                                                    .map((user) {
                                                      final fullName = '${user.getStringValue('forename')} ${user.getStringValue('surname')}'.trim();
                                                      return ListTile(
                                                        title: Text(fullName.isEmpty ? user.getStringValue('email') : fullName),
                                                        subtitle: Text(user.getStringValue('email')),
                                                        onTap: () {
                                                          setSheetState(() {
                                                            drafts.add(_ParticipantDraft(
                                                              user: user,
                                                              fullName: fullName,
                                                              presence: 'present',
                                                              service: serviceController.text.trim().isEmpty ? 'Training' : serviceController.text.trim(),
                                                              duration: durationController.text.trim().isEmpty ? '1.5' : durationController.text.trim(),
                                                              cost: costController.text.trim().isEmpty ? '0' : costController.text.trim(),
                                                              share: '100',
                                                            ));
                                                            applyAutoParticipantShares(drafts);
                                                          });
                                                          Navigator.pop(pickerContext);
                                                        },
                                                      );
                                                    })
                                                    .toList(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Spieler hinzufügen'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: drafts.length,
                        itemBuilder: (context, index) {
                          final draft = drafts[index];
                          final totalPlayers = drafts.length;
                          final autoSharePercent = buildAutoShareText(totalPlayers);
                          if (draft.shareController.text.trim().isEmpty || draft.shareController.text == '100' || draft.shareController.text == '100%') {
                            draft.shareController.text = autoSharePercent;
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          draft.fullName.isEmpty ? draft.user.getStringValue('email') : draft.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => setSheetState(() {
                                          drafts.removeAt(index);
                                          applyAutoParticipantShares(drafts);
                                        }),
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Anwesend', style: TextStyle(fontSize: 13)),
                                          value: draft.presence == 'present',
                                          onChanged: (value) {
                                            setSheetState(() => draft.presence = value == true ? 'present' : 'absent');
                                          },
                                          controlAffinity: ListTileControlAffinity.leading,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  TextField(
                                    controller: draft.shareController,
                                    decoration: InputDecoration(
                                      labelText: 'Anteil (%)',
                                      hintText: autoSharePercent,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Abbrechen'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx, true);
                              },
                              child: const Text('Anlegen'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    if (accepted != true) return;

    setState(() {
      _manualSuggestions.add(
        TrainingSessionSuggestion(
          key: 'manual-${DateTime.now().microsecondsSinceEpoch}',
          title: serviceController.text.trim().isEmpty
              ? (training ? 'Training manuell' : 'Sonstiges manuell')
              : serviceController.text.trim(),
          subtitle: training ? 'Manueller Trainingsvorschlag' : 'Sonstige manuelle Vorlage',
          startAt: selectedDateTime,
          endAt: selectedDateTime.add(const Duration(hours: 1, minutes: 30)),
          participants: drafts.isNotEmpty ? drafts.map((draft) => draft.user).toList() : _trainingUsers,
          isManual: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final revenuePoints = buildRevenuePoints(_invoices);

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Trainings-Vorschläge',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 12),
                if (suggestions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Keine Trainingsvorschläge vorhanden.'),
                    ),
                  )
                else
                  ...suggestions.map((suggestion) {
                    final memberCount = suggestion.participants.isNotEmpty
                        ? suggestion.participants.length
                        : _trainingUsers.length;
                    final presentCount = _attendance[suggestion.key]?.values.where((value) => value == 'present').length ?? 0;
                    final absentCount = _attendance[suggestion.key]?.values.where((value) => value == 'absent').length ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _openAttendanceSheet(suggestion),
                        title: Text(suggestion.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(suggestion.startAt)} bis ${DateFormat('HH:mm').format(suggestion.endAt)}'),
                            Text('${suggestion.subtitle} • $memberCount Spieler'),
                            const SizedBox(height: 4),
                            Text('Anwesend: $presentCount • Abwesend: $absentCount'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ablehnen',
                              onPressed: () => _decideSuggestion(suggestion, false),
                              icon: const Icon(Icons.close, color: Colors.redAccent),
                            ),
                            IconButton(
                              tooltip: 'Annehmen',
                              onPressed: () => _decideSuggestion(suggestion, true),
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openManualDialog(training: true),
                        icon: const Icon(Icons.sports_tennis),
                        label: const Text('Manuell eintragen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final selectedGroup = await _pickManualTemplateGroup();
                          if (selectedGroup != null && mounted) {
                            await _openManualDialog(training: true, sourceGroup: selectedGroup);
                          }
                        },
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Aus Vorlage eintragen'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Umsatz',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 180,
                      child: CustomPaint(
                        painter: _RevenueChartPainter(points: revenuePoints, color: appFrontColor.value),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: revenuePoints
                      .map(
                        (point) => Expanded(
                          child: Text(
                            point.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
      ),
    );
  }
}

enum _BillingMode { invoice, reminder }

class TrainerBillingTab extends StatefulWidget {
  const TrainerBillingTab({super.key});

  @override
  State<TrainerBillingTab> createState() => _TrainerBillingTabState();
}

class _TrainerBillingTabState extends State<TrainerBillingTab> {
  bool _loading = true;
  _BillingMode _mode = _BillingMode.invoice;
  List<RecordModel> _invoices = [];
  List<RecordModel> _reminders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final user = pb.authStore.record as RecordModel;
      final invoices = await pb.collection('invoices').getFullList(
            filter: 'submitted_by = "${user.id}"',
            sort: '-created',
          );
      final reminders = await pb.collection('trainer_reminders').getFullList(
            filter: 'trainer = "${user.id}"',
            sort: '-created',
            expand: 'invoice,customer',
          );
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _reminders = reminders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rechnung konnte nicht geladen werden: $e')),
      );
    }
  }

  bool _invoiceNeedsReminder(RecordModel invoice) {
    final status = invoice.getStringValue('status').trim();
    if (status == 'paid') return false;
    final rawDate = invoice.getStringValue('submission_date').trim().isNotEmpty
        ? invoice.getStringValue('submission_date')
        : invoice.getStringValue('created');
    final created = DateTime.tryParse(rawDate)?.toLocal();
    if (created == null) return false;
    final age = DateTime.now().difference(created).inDays;
    if (status == 'pending') return age >= 14;
    if (status == 'approved') return age >= 30;
    return age >= 21;
  }

  bool _reminderIsDue(RecordModel reminder) {
    if (reminder.getBoolValue('resolved')) return false;
    final created = DateTime.tryParse(reminder.getStringValue('created'))?.toLocal();
    if (created == null) return false;
    final age = DateTime.now().difference(created).inDays;
    final level = reminder.getIntValue('level');
    if (level >= 3) return age >= 2;
    if (level == 2) return age >= 4;
    return age >= 7;
  }

  @override
  Widget build(BuildContext context) {
    final invoiceSuggestions = _invoices.where(_invoiceNeedsReminder).toList();
    final reminderSuggestions = _reminders.where(_reminderIsDue).toList();

    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const PortalBanner(
                  icon: Icons.receipt_long,
                  title: 'Rechnung',
                  subtitle: 'Fällige Rechnungen und Mahnungen im Überblick',
                ),
                const Text(
                  'Rechnung',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SegmentedButton<_BillingMode>(
                  segments: const [
                    ButtonSegment(value: _BillingMode.invoice, label: Text('Rechnung'), icon: Icon(Icons.receipt_long)),
                    ButtonSegment(value: _BillingMode.reminder, label: Text('Mahnung'), icon: Icon(Icons.warning)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) {
                    setState(() => _mode = value.first);
                  },
                ),
                const SizedBox(height: 16),
                if (_mode == _BillingMode.invoice) ...[
                  Text(
                    'Vorschläge aus fälligen Rechnungen: ${invoiceSuggestions.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (invoiceSuggestions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Keine fälligen Rechnungen gefunden.'),
                      ),
                    )
                  else
                    ...invoiceSuggestions.map((invoice) {
                      final created = DateTime.tryParse(invoice.getStringValue('submission_date').trim().isNotEmpty
                              ? invoice.getStringValue('submission_date')
                              : invoice.getStringValue('created'))
                          ?.toLocal();
                      final age = created == null ? 0 : DateTime.now().difference(created).inDays;
                      final amount = invoice.getDoubleValue('amount');
                      return Card(
                        child: ListTile(
                          title: Text('${invoice.getStringValue('description')} • € ${amount.toStringAsFixed(2)}'),
                          subtitle: Text('Fällig seit $age Tagen • Status: ${invoice.getStringValue('status')}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                      );
                    }),
                ] else ...[
                  Text(
                    'Mahnungsvorschläge: ${reminderSuggestions.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (reminderSuggestions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Keine fälligen Mahnungen gefunden.'),
                      ),
                    )
                  else
                    ...reminderSuggestions.map((reminder) {
                      final created = DateTime.tryParse(reminder.getStringValue('created'))?.toLocal();
                      final age = created == null ? 0 : DateTime.now().difference(created).inDays;
                      final invoice = reminder.get<List<RecordModel>>('expand.invoice').isNotEmpty
                          ? reminder.get<List<RecordModel>>('expand.invoice').first
                          : null;
                      final amount = invoice?.getDoubleValue('amount') ?? 0.0;
                      final customer = reminder.get<List<RecordModel>>('expand.customer').isNotEmpty
                          ? reminder.get<List<RecordModel>>('expand.customer').first
                          : null;
                      final customerName = customer == null
                          ? 'Unbekannter Kunde'
                          : '${customer.getStringValue('forename')} ${customer.getStringValue('surname')}'.trim();
                      return Card(
                        child: ListTile(
                          title: Text('$customerName • € ${amount.toStringAsFixed(2)}'),
                          subtitle: Text('Stufe ${reminder.getIntValue('level')} • fällig seit $age Tagen'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    }),
                ],
              ],
            ),
    );
  }
}

class TrainerManageTab extends StatelessWidget {
  const TrainerManageTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: PortalBanner(
              icon: Icons.manage_accounts,
              title: 'Verwalten',
              subtitle: 'Rechnungen, Mahnungen und Leistungen organisieren',
            ),
          ),
          Material(
            color: Colors.transparent,
            child: TabBar(
              tabs: [
                Tab(text: 'Rechnungen'),
                Tab(text: 'Mahnungen'),
                Tab(text: 'Leistungen'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                TrainerInvoicesTab(),
                TrainerRemindersTab(),
                TrainerServicesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrainerRosterPage extends StatefulWidget {
  const TrainerRosterPage({super.key});

  @override
  State<TrainerRosterPage> createState() => _TrainerRosterPageState();
}

class _TrainerRosterPageState extends State<TrainerRosterPage> {
  bool _loading = true;
  List<RecordModel> _trainers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isTrainerUser(RecordModel user) {
    if (user.getBoolValue('auth_admin_trainer')) return true;
    if (user.getIntValue('perm_trainer_trainer') > 0) return true;
    if (user.getIntValue('perm_trainer_member') > 0) return true;
    if (user.getIntValue('perm_trainer_bill') > 0) return true;
    if (user.getIntValue('perm_trainer_reminder') > 0) return true;

    final rawRoles = user.toJson()['roles'];
    if (rawRoles is List) {
      for (final role in rawRoles) {
        final roleValue = role.toString().toLowerCase();
        if (roleValue.contains('trainer')) return true;
      }
    }

    final rawRole = user.toJson()['role'];
    if (rawRole is String) {
      final roleValue = rawRole.toLowerCase();
      if (roleValue.contains('trainer')) return true;
    }

    return false;
  }

  Future<void> _load() async {
    try {
      final users = await pb.collection('users').getFullList(sort: 'surname,forename');
      final trainers = users.where(_isTrainerUser).toList();

      if (!mounted) return;
      setState(() {
        _trainers = trainers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trainerstamm konnte nicht geladen werden: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trainerstamm')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _trainers.length,
              itemBuilder: (context, index) {
                final trainer = _trainers[index];
                final fullName = '${trainer.getStringValue('forename')} ${trainer.getStringValue('surname')}'.trim();
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        fullName.isEmpty
                            ? 'T'
                            : fullName[0].toUpperCase(),
                      ),
                    ),
                    title: Text(fullName.isEmpty ? trainer.getStringValue('email') : fullName),
                    subtitle: Text(trainer.getStringValue('email')),
                  ),
                );
              },
            ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  final List<MonthlyRevenuePoint> points;
  final Color color;

  _RevenueChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final barWidth = size.width / (points.length * 1.4);
    final maxAmount = points.map((e) => e.amount).fold<double>(0, max);
    final baseline = size.height - 24;
    final paint = Paint()..color = color;

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final height = maxAmount == 0
          ? 0.0
          : (point.amount / maxAmount) * (size.height - 40);
      final left = i * barWidth * 1.4 + barWidth * 0.2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseline - height, barWidth, height),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}