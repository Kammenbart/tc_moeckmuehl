import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'settings_service.dart';

class EmailService {
  final AppSettingsService settings;

  EmailService(this.settings);

  /// Attempt to send an email using SMTP settings stored in settings collection.
  /// Returns true on success, false on failure or when SMTP not configured.
  Future<bool> sendFeedback({
    required String to,
    required String subject,
    required String body,
    String? fromEmail,
    String? fromName,
  }) async {
    try {
      final cfg = await settings.loadSettings([
        'smtp_host',
        'smtp_port',
        'smtp_username',
        'smtp_password',
        'smtp_secure',
      ]);

      final host = cfg['smtp_host'] ?? '';
      if (host.isEmpty) return false; // no SMTP configured

      final port = int.tryParse(cfg['smtp_port'] ?? '') ?? 587;
      final username = cfg['smtp_username'] ?? '';
      final password = cfg['smtp_password'] ?? '';
      final secure = (cfg['smtp_secure'] ?? 'true').toLowerCase() == 'true';

      final smtp = SmtpServer(host,
          port: port,
          username: username.isNotEmpty ? username : null,
          password: password.isNotEmpty ? password : null,
          ssl: secure);

      final fromAddress = Address(
        username.isNotEmpty ? username : (fromEmail ?? 'noreply@local'),
        fromName ?? 'TC Möckmühl App',
      );

      final message = Message()
        ..from = fromAddress
        ..recipients.add(to)
        ..subject = subject
        ..text = body;

      if (fromEmail != null && fromEmail.isNotEmpty && fromEmail != username) {
        message.headers['Reply-To'] = fromEmail;
      }

      final sendReport = await send(message, smtp);
      debugPrint('Email send report: $sendReport');
      return true;
    } catch (e) {
      debugPrint('Email send failed: $e');
      return false;
    }
  }
}
