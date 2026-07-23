import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

class AppSettingsService {
  final PocketBase pb;

  AppSettingsService(this.pb);

  /// Load multiple settings by name and return a map name->value
  Future<Map<String, String>> loadSettings(List<String> names) async {
    final result = <String, String>{};
    if (names.isEmpty) return result;

    try {
      // Build filter like: name = "a" || name = "b"
      final filter = names.map((n) => 'name = "$n"').join(' || ');
      final records = await pb.collection('settings').getFullList(filter: filter);
      for (final r in records) {
        final name = r.getStringValue('name');
        final value = r.getStringValue('value');
        if (name.isNotEmpty) result[name] = value;
      }
    } catch (e) {
      debugPrint('Settings load failed: $e');
    }

    return result;
  }

  /// Save multiple settings. Creates new records if missing, updates existing ones.
  Future<void> saveSettings(Map<String, String> kv) async {
    if (kv.isEmpty) return;

    try {
      final names = kv.keys.toList();
      final filter = names.map((n) => 'name = "$n"').join(' || ');
      final existing = await pb.collection('settings').getFullList(filter: filter);
      final existingByName = {for (var r in existing) r.getStringValue('name'): r};

      for (final entry in kv.entries) {
        final name = entry.key;
        final value = entry.value;
        final rec = existingByName[name];
        if (rec != null) {
          await pb.collection('settings').update(rec.id, body: {'value': value});
        } else {
          await pb.collection('settings').create(body: {'name': name, 'value': value});
        }
      }
    } catch (e) {
      debugPrint('Settings save failed: $e');
      rethrow;
    }
  }

  /// Migration helper: if an old combined settings record exists with id [oldRecordId],
  /// copy specific fields into individual name/value records.
  Future<void> migrateCombinedRecord(String oldRecordId, List<String> keys) async {
    try {
      final rec = await pb.collection('settings').getOne(oldRecordId);

      final toSave = <String, String>{};
      for (final k in keys) {
        final v = rec.getStringValue(k);
        if (v.isNotEmpty) toSave[k] = v;
      }

      if (toSave.isNotEmpty) {
        await saveSettings(toSave);
      }
    } catch (e) {
      // ignore: don't fail startup on migration error
      debugPrint('Settings migration skipped/failed: $e');
    }
  }
}
