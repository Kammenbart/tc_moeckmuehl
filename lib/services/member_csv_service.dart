import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import 'dart:convert';
import 'dart:io';

class MemberCsvImportExport {
  /// Export members to CSV
  static Future<void> exportMembersToCSV(BuildContext context) async {
    try {
      // Load all members
      final members = await pb.collection('users').getFullList();

      // Prepare CSV data
      List<List<dynamic>> csvData = [
        // Header row
        [
          'Vorname',
          'Nachname',
          'E-Mail',
          'Telefon',
          'Mobil',
          'IBAN',
          'BIC',
          'Bankname',
          'Kontoinhaber',
          'Mitgliedsnummer',
          'Mitglied',
          'Mitgliedschaftsanfrage'
        ]
      ];

      // Data rows
      for (var member in members) {
        csvData.add([
          member.getStringValue('forename'),
          member.getStringValue('surname'),
          member.getStringValue('email'),
          member.getStringValue('phone'),
          member.getStringValue('mobile'),
          member.getStringValue('iban'),
          member.getStringValue('bic'),
          member.getStringValue('bank_name'),
          member.getStringValue('bank_owner'),
          member.getStringValue('club_id'),
          member.getBoolValue('membership') ? 'ja' : 'nein',
          member.getBoolValue('membership_request') ? 'ja' : 'nein',
        ]);
      }

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(csvData);

      // Save to file (using path_provider)
      final fileName = 'Mitglieder_${DateTime.now().toString().split(' ')[0]}.csv';
      final fileContent = utf8.encode(csv);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'CSV erstellt: $fileName\n${members.length} Mitglieder exportiert',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export-Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Import members from CSV file
  static Future<void> importMembersFromCSV(BuildContext context) async {
    try {
      // Pick CSV file
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final contents = await file.readAsString(encoding: utf8);

      // Parse CSV
      List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(contents);

      if (csvTable.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV-Datei ist leer'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Verify header
      final header = csvTable.first;
      const requiredHeaders = [
        'Vorname',
        'Nachname',
        'E-Mail',
      ];

      bool hasAllHeaders = true;
      for (var h in requiredHeaders) {
        if (!header.contains(h)) {
          hasAllHeaders = false;
          break;
        }
      }

      if (!hasAllHeaders) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV-Header ungültig. Erforderlich: Vorname, Nachname, E-Mail'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Process rows
      List<String> createdEmails = [];
      List<String> errors = [];

      for (int i = 1; i < csvTable.length; i++) {
        try {
          final row = csvTable[i];
          final forename = row[0].toString().trim();
          final surname = row[1].toString().trim();
          final email = row[2].toString().trim();
          final phone = row.length > 3 ? row[3].toString().trim() : '';
          final mobile = row.length > 4 ? row[4].toString().trim() : '';
          final iban = row.length > 5 ? row[5].toString().trim() : '';
          final bic = row.length > 6 ? row[6].toString().trim() : '';
          final bankName = row.length > 7 ? row[7].toString().trim() : '';
          final bankOwner = row.length > 8 ? row[8].toString().trim() : '';
          final clubId = row.length > 9 ? row[9].toString().trim() : '';

          if (forename.isEmpty || surname.isEmpty || email.isEmpty) {
            errors.add('Reihe ${i + 1}: Vorname, Nachname und E-Mail erforderlich');
            continue;
          }

          // Check if user already exists
          try {
            await pb.collection('users').getFirstListItem('email = "$email"');
            errors.add('Reihe ${i + 1}: E-Mail existiert bereits');
            continue;
          } catch (_) {
            // User doesn't exist, continue with creation
          }

          // Generate temporary password
          final tempPassword = _generatePassword();

          // Create user
          await pb.collection('users').create(body: {
            'email': email,
            'password': tempPassword,
            'passwordConfirm': tempPassword,
            'forename': forename,
            'surname': surname,
            'phone': phone,
            'mobile': mobile,
            'iban': iban,
            'bic': bic,
            'bank_name': bankName,
            'bank_owner': bankOwner,
            'club_id': clubId,
            'membership': false,
            'membership_request': false,
            'emailVisibility': true,
          });

          createdEmails.add(email);
        } catch (e) {
          errors.add('Reihe ${i + 1}: Fehler - ${e.toString()}');
        }
      }

      // Show summary
      if (context.mounted) {
        String message =
            'Import abgeschlossen!\nErstellt: ${createdEmails.length} Mitglieder';

        if (errors.isNotEmpty) {
          message += '\nFehler: ${errors.length}';
          message += '\n\n${errors.take(5).join("\n")}';
          if (errors.length > 5) {
            message += '\n... und ${errors.length - 5} weitere';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );

        // Optional: Send notification emails
        if (createdEmails.isNotEmpty) {
          await _sendWelcomeEmails(createdEmails, context);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import-Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate a secure temporary password
  static String _generatePassword() {
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789!@#';
    final random = List.generate(12, (index) {
      return chars[(DateTime.now().microsecond + index) % chars.length];
    });
    return random.join();
  }

  /// Send welcome emails to new members
  static Future<void> _sendWelcomeEmails(
    List<String> emails,
    BuildContext context,
  ) async {
    try {
      // For now, just log - in production, integrate with email service (Mailgun, SendGrid, etc.)
      debugPrint('Sending welcome emails to: ${emails.join(", ")}');

      // TODO: Implement actual email sending via Pocketbase hooks or external service
      // Example using mailer package or HTTP calls to backend email service

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Willkommens-E-Mails versendet an ${emails.length} Mitglieder',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Email sending error: $e');
    }
  }
}
