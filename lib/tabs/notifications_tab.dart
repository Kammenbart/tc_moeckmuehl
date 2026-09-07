import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../main.dart';
import '../services/notification_workflow_service.dart';

class NotificationsTab extends StatefulWidget {
  final bool embedded;

  const NotificationsTab({super.key, this.embedded = false});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<RecordModel> items = [];
  bool loading = true;
  String? _activeActionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final user = pb.authStore.record;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        items = [];
        loading = false;
      });
      return;
    }

    try {
      final all = await _fetchNotificationCandidates(user);
      final filtered = all
          .where((n) => _isVisibleForUser(n, user))
          .toList()
        ..sort(_compareNotifications);

      if (!mounted) return;
      final openCount = filtered.where(isOpenNotificationForBadge).length;
      if (!mounted) return;
      setState(() {
        items = filtered;
        loading = false;
      });
      openNotificationsBadgeCount.value = openCount;
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Laden der Mitteilungen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<RecordModel>> _fetchNotificationCandidates(
    RecordModel user,
  ) async {
    final base = await pb.collection('notifications').getFullList(
          sort: '-created',
          expand: 'decided_by,checked_by',
        );
    if (base.isNotEmpty) {
      return base;
    }

    // Fallback for stricter list rules in PocketBase: fetch with common
    // user/scope filters and merge unique records.
    final userId = user.id;
    final email = user.getStringValue('email').trim();
    final scopeTokens = <String>{};
    if (user.getBoolValue('auth_admin_board')) {
      scopeTokens
        ..add('auth_admin_board')
        ..add('board')
        ..add('vorstand');
    }
    if (user.getBoolValue('auth_admin_trainer')) {
      scopeTokens
        ..add('auth_admin_trainer')
        ..add('trainer');
    }
    if (user.getBoolValue('auth_admin_app')) {
      scopeTokens
        ..add('auth_admin_app')
        ..add('app')
        ..add('admin_app');
    }

    final filters = <String>{
      'user = "$userId"',
      'user ~ "$userId"',
      if (email.isNotEmpty) 'user_email = "$email"',
      if (email.isNotEmpty) 'user_email ~ "$email"',
      ...scopeTokens.map((token) => 'scope ~ "$token"'),
    };

    final byId = <String, RecordModel>{};
    for (final f in filters) {
      try {
        final list = await pb.collection('notifications').getFullList(
              filter: f,
              sort: '-created',
              expand: 'decided_by,checked_by',
            );
        for (final n in list) {
          byId[n.id] = n;
        }
      } catch (_) {
        // Ignore invalid filters for varying field schemas.
      }
    }

    return byId.values.toList();
  }

  bool _isVisibleForUser(RecordModel notification, RecordModel user) {
    final myUserTokens = <String>{
      user.id.toLowerCase(),
      user.getStringValue('email').trim().toLowerCase(),
      user.getStringValue('username').trim().toLowerCase(),
    }..removeWhere((e) => e.isEmpty);

    final directUserTokens = <String>{
      notification.getStringValue('user').trim().toLowerCase(),
      ...List<String>.from(notification.getListValue('user').cast<String>())
          .map((e) => e.trim().toLowerCase()),
      notification.getStringValue('user_email').trim().toLowerCase(),
    }..removeWhere((e) => e.isEmpty);

    final isDirectUser = directUserTokens.any(myUserTokens.contains);

    final myGroups = <String>{};
    if (user.getBoolValue('auth_admin_board')) {
      myGroups
        ..add('auth_admin_board')
        ..add('board')
        ..add('vorstand');
    }
    if (user.getBoolValue('auth_admin_trainer')) {
      myGroups
        ..add('auth_admin_trainer')
        ..add('trainer');
    }
    if (user.getBoolValue('auth_admin_app')) {
      myGroups
        ..add('auth_admin_app')
        ..add('app')
        ..add('admin_app');
    }

    final rawScope = notification.getStringValue('scope').trim();
    final scopeAsList = List<String>.from(
      notification.getListValue('scope').cast<String>(),
    );

    final scopeTokens = <String>{...scopeAsList};
    if (rawScope.isNotEmpty) {
      scopeTokens.addAll(
        rawScope
            .split(RegExp(r'[,;\s]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
      scopeTokens.add(rawScope);
    }

    final normalizedScopes = scopeTokens
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    final hasGroupScope = myGroups.any(normalizedScopes.contains);
    return isDirectUser || hasGroupScope;
  }

  int _priorityRank(String priority) {
    switch (priority) {
      case 'urgent':
        return 0;
      case 'important':
        return 1;
      case 'normal':
        return 2;
      default:
        return 3;
    }
  }

  int _compareNotifications(RecordModel a, RecordModel b) {
    final aUnprocessed =
        a.getStringValue('state').trim().isEmpty &&
        a.getStringValue('decision_state').trim() != 'applied';
    final bUnprocessed =
        b.getStringValue('state').trim().isEmpty &&
        b.getStringValue('decision_state').trim() != 'applied';
    if (aUnprocessed != bUnprocessed) {
      return aUnprocessed ? -1 : 1;
    }

    final aRead = a.getBoolValue('is_read');
    final bRead = b.getBoolValue('is_read');
    if (aRead != bRead) {
      return aRead ? 1 : -1;
    }

    final aDate = DateTime.tryParse(a.getStringValue('created'));
    final bDate = DateTime.tryParse(b.getStringValue('created'));
    final dateCmp = (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
    if (dateCmp != 0) {
      return dateCmp;
    }

    final aPriority = _priorityRank(a.getStringValue('priority'));
    final bPriority = _priorityRank(b.getStringValue('priority'));
    return aPriority.compareTo(bPriority);
  }

  Future<void> _applyState(RecordModel notification, String state) async {
    final user = pb.authStore.record;
    if (user == null) return;
    if (_activeActionId != null) return;

    setState(() => _activeActionId = notification.id);
    try {
      await NotificationWorkflowService.applyDecision(
        notification: notification,
        actor: user,
        state: state,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aktion konnte nicht gespeichert werden: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _activeActionId = null);
      }
    }
  }

  String _priorityMarker(String priority) {
    switch (priority) {
      case 'urgent':
        return '!!';
      case 'important':
        return '!';
      default:
        return '';
    }
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'read':
        return Colors.blue;
      case 'enabled':
        return Colors.green;
      case 'disabled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _personName(RecordModel notification) {
    final expanded = notification.get<List<RecordModel>>('expand.decided_by');
    if (expanded.isNotEmpty) {
      final checker = expanded.first;
      final forename = checker.getStringValue('forename').trim();
      final surname = checker.getStringValue('surname').trim();
      final full = '$forename $surname'.trim();
      if (full.isNotEmpty) return full;
      final email = checker.getStringValue('email').trim();
      if (email.isNotEmpty) return email;
    }

    final legacy = notification.get<List<RecordModel>>('expand.checked_by');
    if (legacy.isNotEmpty) {
      final checker = legacy.first;
      final forename = checker.getStringValue('forename').trim();
      final surname = checker.getStringValue('surname').trim();
      final full = '$forename $surname'.trim();
      if (full.isNotEmpty) return full;
    }

    return 'Unbekannt';
  }

  String _stateText(String state, String checkedByName) {
    switch (state) {
      case 'read':
        return 'Gelesen von $checkedByName';
      case 'enabled':
        return 'Genehmigt durch $checkedByName';
      case 'disabled':
        return 'Abgelehnt durch $checkedByName';
      default:
        return 'Status: ${state.toUpperCase()}';
    }
  }

  String _decisionStateText(RecordModel notification) {
    final decision = notification.getStringValue('decision_state').trim();
    final reason = notification.getStringValue('decision_reason').trim();
    switch (decision) {
      case 'pending':
        return 'Entscheidung ausstehend';
      case 'approved':
        return 'Entscheidung erfasst: genehmigt';
      case 'rejected':
        return 'Entscheidung erfasst: abgelehnt';
      case 'applied':
        return 'Aktion erfolgreich angewendet';
      case 'failed':
        return reason.isEmpty
            ? 'Aktion fehlgeschlagen'
            : 'Aktion fehlgeschlagen: $reason';
      default:
        return '';
    }
  }

  Widget _buildActions(RecordModel n, bool done) {
    final category = n.getStringValue('category');
    final disabled = done || _activeActionId == n.id;

    if (category == 'action_required') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: disabled ? null : () => _applyState(n, 'enabled'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green.shade700,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Genehmigen'),
          ),
          TextButton.icon(
            onPressed: disabled ? null : () => _applyState(n, 'disabled'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Ablehnen'),
          ),
        ],
      );
    }

    if (category == 'info' || category == 'warning') {
      return TextButton.icon(
        onPressed: disabled ? null : () => _applyState(n, 'read'),
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Gelesen'),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final content = loading
        ? const Center(child: CircularProgressIndicator())
        : items.isEmpty
            ? const Center(child: Text('Keine Mitteilungen vorhanden.'))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final n = items[i];
                    final title = n.getStringValue('title');
                    final message = n.getStringValue('message');
                    final priority = n.getStringValue('priority');
                    final marker = _priorityMarker(priority);
                    final state = n.getStringValue('state').trim();
                    final decisionState = n.getStringValue('decision_state').trim();
                    final done =
                      state.isNotEmpty ||
                      decisionState == 'applied' ||
                      decisionState == 'failed';
                    final checkedByName = _personName(n);
                    final decisionHint = _decisionStateText(n);

                    final created =
                        DateTime.tryParse(n.getStringValue('created'))?.toLocal();
                    final createdStr = DateFormat(
                      'EEEE, dd.MM.yyyy HH:mm',
                      'de_DE',
                    ).format(created ?? DateTime.now());

                    final fgColor = done ? Colors.grey.shade600 : Colors.black87;
                    final cardColor = done
                        ? Colors.grey.shade200
                        : Theme.of(context).cardColor;

                    return Card(
                      color: cardColor,
                      child: ListTile(
                        title: Text(
                          '${marker.isEmpty ? '' : '$marker '}${title.isEmpty ? '(Ohne Titel)' : title}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: fgColor,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message,
                                style: TextStyle(color: fgColor),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                createdStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (done) ...[
                                const SizedBox(height: 8),
                                if (state.isNotEmpty)
                                  Text(
                                    _stateText(state, checkedByName),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _stateColor(state),
                                    ),
                                  ),
                                if (decisionHint.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      decisionHint,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: decisionState == 'failed'
                                            ? Colors.red.shade700
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                              ],
                              if (!done) ...[
                                const SizedBox(height: 8),
                                _buildActions(n, done),
                              ],
                            ],
                          ),
                        ),
                        onTap: () {
                          if (message.isEmpty) return;
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(title.isEmpty ? '(Ohne Titel)' : title),
                              content: Text(message),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Schließen'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitteilungen'),
      ),
      body: content,
    );
  }
}