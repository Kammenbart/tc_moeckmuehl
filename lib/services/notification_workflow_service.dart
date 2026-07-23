import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

import '../main.dart';

class NotificationWorkflowService {
  static Future<void> createBeverageCancelRequest({
    required String orderId,
    required String articleName,
    required String requesterName,
    required String dateLabel,
  }) async {
    final safeArticle = articleName.replaceAll('"', '\\"');
    final actor = pb.authStore.record;
    await pb.collection('notifications').create(
      body: {
        'title': 'Getraenkestorno anfragen',
        'message':
            'Fuer Artikel $safeArticle wurde von $requesterName am $dateLabel eine Stornierung angefragt.',
        'category': 'action_required',
        'priority': 'normal',
        'scope': 'auth_admin_board',
        'action_type': 'beverage_cancel',
        'action_target': 'beverage_orders/$orderId',
        'user': actor?.id,
        'user_email': actor?.getStringValue('email') ?? '',
        'action_payload': jsonEncode({
          'order_id': orderId,
          'article_name': articleName,
          'requester_name': requesterName,
          'date': dateLabel,
          'requester_id': actor?.id,
          'requester_email': actor?.getStringValue('email') ?? '',
        }),
        'decision_state': 'pending',
      },
    );
  }

  static Future<void> createMembershipRequest({
    required RecordModel requester,
  }) async {
    final actor = pb.authStore.record;
    final fullName = [
      requester.getStringValue('forename'),
      requester.getStringValue('surname'),
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();
    final displayName = fullName.isEmpty
        ? requester.getStringValue('email')
        : fullName;

    await pb.collection('notifications').create(
      body: {
        'title': 'Mitgliedschaftsanfrage',
        'message': '$displayName hat eine Mitgliedschaftsanfrage gestellt.',
        'category': 'action_required',
        'priority': 'important',
        'scope': 'auth_admin_board',
        'action_type': 'membership_request',
        'action_target': 'users/${requester.id}',
        'user': requester.id,
        'user_email': requester.getStringValue('email'),
        'action_payload': jsonEncode({
          'user_id': requester.id,
          'user_name': displayName,
          'requester_id': actor?.id,
        }),
        'decision_state': 'pending',
      },
    );
  }

  static Future<void> applyDecision({
    required RecordModel notification,
    required RecordModel actor,
    required String state,
  }) async {
    final needsAction =
        notification.getStringValue('category').trim() == 'action_required';
    var actionType = notification.getStringValue('action_type').trim();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    String decisionState = 'applied';
    if (needsAction && state == 'enabled') decisionState = 'approved';
    if (needsAction && state == 'disabled') decisionState = 'rejected';

    await _updateNotificationWithFallback(
      notification.id,
      {
        'decision_state': decisionState,
        'decided_by': actor.id,
        'decided_at': nowIso,
        'state': state,
        'checked_by': actor.id,
        'is_read': true,
        'decision_reason': '',
      },
    );

    if (!needsAction) {
      return;
    }

    if (actionType.isEmpty) {
      actionType = _inferActionType(notification);
      if (actionType.isNotEmpty) {
        await _updateNotificationWithFallback(
          notification.id,
          {
            'action_type': actionType,
            'decision_reason': '',
          },
        );
      }
    }

    if (actionType.isEmpty) {
      await _updateNotificationWithFallback(
        notification.id,
        {
          'decision_state': 'failed',
          'decided_by': actor.id,
          'decided_at': nowIso,
          'decision_reason':
              'Keine Aktion hinterlegt (action_type fehlt). Bitte Anfrage neu erstellen.',
          'is_read': true,
        },
      );
      throw Exception(
        'Keine Aktion hinterlegt (action_type fehlt). Bitte Anfrage neu erstellen.',
      );
    }

    try {
      await _runAction(
        notification,
        approved: state == 'enabled',
        actionTypeOverride: actionType,
      );
      await _updateNotificationWithFallback(
        notification.id,
        {
          'decision_state': 'applied',
          'decided_by': actor.id,
          'decided_at': nowIso,
          'state': state,
          'checked_by': actor.id,
          'is_read': true,
        },
      );
    } catch (e) {
      await _updateNotificationWithFallback(
        notification.id,
        {
          'decision_state': 'failed',
          'decided_by': actor.id,
          'decided_at': nowIso,
          'decision_reason': e.toString(),
          'is_read': true,
        },
      );
      rethrow;
    }
  }

  static Future<void> _runAction(
    RecordModel notification, {
    required bool approved,
    String? actionTypeOverride,
  }) async {
    final actionType =
        (actionTypeOverride ?? notification.getStringValue('action_type')).trim();
    if (actionType.isEmpty) return;

    final payload = _parsePayload(notification.getStringValue('action_payload'));
    final target = _parseActionTarget(
      notification.getStringValue('action_target'),
      actionType,
      payload,
    );

    switch (actionType) {
      case 'beverage_cancel':
        if (target.id.isEmpty) {
          throw Exception('Kein Ziel fuer Getraenkestorno gefunden.');
        }
        if (approved) {
          try {
            await pb.collection(target.collection).delete(target.id);
          } catch (e) {
            final text = e.toString().toLowerCase();
            if (!text.contains('404') && !text.contains('not found')) {
              rethrow;
            }
          }
        } else {
          await pb.collection(target.collection).update(
            target.id,
            body: {'cancel_requested': false},
          );
        }
        break;

      case 'membership_request':
        if (target.id.isEmpty) {
          throw Exception('Kein Ziel fuer Mitgliedschaftsanfrage gefunden.');
        }
        await pb.collection(target.collection).update(
          target.id,
          body: {
            'membership': approved,
            'membership_request': false,
          },
        );
        break;

      default:
        break;
    }
  }

  static String _inferActionType(RecordModel notification) {
    final target = notification.getStringValue('action_target').trim();
    if (target.startsWith('beverage_orders/') ||
        target.startsWith('beverage_orders:')) {
      return 'beverage_cancel';
    }
    if (target.startsWith('users/') || target.startsWith('users:')) {
      return 'membership_request';
    }

    final payload = _parsePayload(notification.getStringValue('action_payload'));
    if (payload['order_id'] != null) {
      return 'beverage_cancel';
    }
    if (payload['user_id'] != null) {
      return 'membership_request';
    }

    final message = notification.getStringValue('message').toLowerCase();
    if (message.contains('stornierung')) {
      return 'beverage_cancel';
    }
    if (message.contains('mitgliedschaft')) {
      return 'membership_request';
    }

    return '';
  }

  static ({String collection, String id}) _parseActionTarget(
    String rawTarget,
    String actionType,
    Map<String, dynamic> payload,
  ) {
    String collection = '';
    String id = '';

    final target = rawTarget.trim();
    if (target.contains('/')) {
      final parts = target.split('/');
      if (parts.length >= 2) {
        collection = parts.first.trim();
        id = parts.sublist(1).join('/').trim();
      }
    } else if (target.contains(':')) {
      final idx = target.indexOf(':');
      collection = target.substring(0, idx).trim();
      id = target.substring(idx + 1).trim();
    } else if (target.isNotEmpty) {
      id = target;
    }

    if (collection.isEmpty) {
      switch (actionType) {
        case 'beverage_cancel':
          collection = 'beverage_orders';
          break;
        case 'membership_request':
          collection = 'users';
          break;
      }
    }

    if (id.isEmpty) {
      final payloadId = payload['record_id'] ??
          payload['target_id'] ??
          payload['order_id'] ??
          payload['user_id'];
      if (payloadId != null) {
        id = payloadId.toString().trim();
      }
    }

    return (collection: collection, id: id);
  }

  static Map<String, dynamic> _parsePayload(String rawPayload) {
    final payload = rawPayload.trim();
    if (payload.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      // payload can be plain text
    }
    return <String, dynamic>{};
  }

  static Future<void> _updateNotificationWithFallback(
    String notificationId,
    Map<String, dynamic> body,
  ) async {
    try {
      await pb.collection('notifications').update(notificationId, body: body);
    } catch (e) {
      final fallback = Map<String, dynamic>.from(body);
      if (fallback.containsKey('decided_at')) {
        fallback['decided_at'] = pb.authStore.record?.id;
      }
      await pb.collection('notifications').update(notificationId, body: fallback);
    }
  }
}
