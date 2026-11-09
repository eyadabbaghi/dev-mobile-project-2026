import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../models/community_notification.dart';
import '../utils/community_formatters.dart';
import 'community_dialogs.dart';

Future<void> showCommunityNotificationsSheet(
  BuildContext context, {
  required CommunityRepository repository,
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CommunityNotificationsSheet(
      repository: repository,
      userId: userId,
    ),
  );
}

class CommunityNotificationsSheet extends StatefulWidget {
  const CommunityNotificationsSheet({
    super.key,
    required this.repository,
    required this.userId,
  });

  final CommunityRepository repository;
  final String userId;

  @override
  State<CommunityNotificationsSheet> createState() =>
      _CommunityNotificationsSheetState();
}

class _CommunityNotificationsSheetState
    extends State<CommunityNotificationsSheet> {
  List<CommunityNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.getNotifications(widget.userId);
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _markRead(CommunityNotification notification) async {
    if (notification.isRead) return;
    try {
      await widget.repository.markNotificationRead(notification.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.repository.markAllNotificationsRead(widget.userId);
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCommunitySnack(context, communityErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unread = _notifications.where((item) => !item.isRead).length;

    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        unread == 0
                            ? 'Tout est à jour'
                            : '$unread non lue${unread == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text('Tout lire'),
                  ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text('Aucune notification'),
            const SizedBox(height: 4),
            Text(
              'Les réactions, commentaires et mentions apparaîtront ici.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final colors = theme.colorScheme;
        return ListTile(
          onTap: () => _markRead(notification),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: notification.isRead
                ? colors.surfaceContainerHighest
                : colors.primary.withValues(alpha: 0.18),
            child: Icon(
              notification.type.icon,
              size: 18,
              color: notification.isRead ? colors.onSurfaceVariant : colors.primary,
            ),
          ),
          title: Text(
            notification.message,
            style: TextStyle(
              fontWeight: notification.isRead
                  ? FontWeight.w500
                  : FontWeight.w700,
            ),
          ),
          subtitle: Text(formatPostTime(notification.createdAt)),
          trailing: notification.isRead
              ? null
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
        );
      },
    );
  }
}
