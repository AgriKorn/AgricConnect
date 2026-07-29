import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/notifications_repository.dart';

/// Farmer/buyer/driver notification feed — real events from the backend
/// (purchases, dispatch offers, disputes, deliveries), not a role-specific
/// order-management view.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  bool _loading = true;
  List<AppNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notifications = await ref.read(notificationsRepositoryProvider).fetchNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _loading = false;
    });
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    setState(() {
      _notifications = [
        for (final n in _notifications)
          if (n.id == notification.id)
            AppNotification(
              id: n.id,
              title: n.title,
              message: n.message,
              timeAgo: n.timeAgo,
              isRead: true,
              orderId: n.orderId,
              listingId: n.listingId,
            )
          else
            n,
      ];
    });
    await ref.read(notificationsRepositoryProvider).markAsRead(notification.id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                      ? ListView(
                          children: const [
                            EmptyState(
                              icon: Icons.notifications_none_rounded,
                              message: 'No notifications yet.',
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 18),
                            ..._notifications.map((n) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _NotificationTile(
                                    notification: n,
                                    colorScheme: colorScheme,
                                    onTap: () => _markAsRead(n),
                                  ),
                                )),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.colorScheme, required this.onTap});

  final AppNotification notification;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
              : colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.isRead ? colorScheme.outline.withValues(alpha: 0.2) : colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, right: 10),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      Text(
                        notification.timeAgo,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
