import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/agri_toast.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/notifications_providers.dart';
import '../data/notifications_mock.dart';

const _tabs = ['Active', 'Completed', 'Cancelled'];

/// Farmer's notification feed: dispatch/order updates that need attention
/// (In Transit / Pending Pickup) alongside completed and cancelled history.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _selectedTab = 'Active';
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _inTab(OrderNotification notification) => switch (_selectedTab) {
    'Active' => notification.status == DispatchStatus.inTransit || notification.status == DispatchStatus.pendingPickup,
    'Completed' => notification.status == DispatchStatus.delivered,
    'Cancelled' => notification.status == DispatchStatus.cancelled,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final query = _searchController.text.trim().toLowerCase();
    final notifications = ref
        .watch(orderNotificationsProvider)
        .where(_inTab)
        .where((n) =>
            query.isEmpty ||
            n.customerName.toLowerCase().contains(query) ||
            n.itemSummary.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      _CircleIconButton(
                        colorScheme: colorScheme,
                        icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                        onPressed: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) _searchController.clear();
                        }),
                      ),
                    ],
                  ),
                ),
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: colorScheme.onSurface),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        hintText: 'Search by customer or item...',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                        prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        for (final tab in _tabs)
                          Expanded(
                            child: _TabButton(
                              label: tab,
                              active: tab == _selectedTab,
                              colorScheme: colorScheme,
                              onTap: () => setState(() => _selectedTab = tab),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: notifications.isEmpty
                      ? EmptyState(
                          icon: Icons.notifications_none_rounded,
                          message: 'No ${_selectedTab.toLowerCase()} notifications.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                          itemCount: notifications.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) =>
                              _NotificationCard(notification: notifications[index], colorScheme: colorScheme),
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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.colorScheme, required this.icon, required this.onPressed});

  final ColorScheme colorScheme;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: colorScheme.onSurface, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.colorScheme, required this.onTap});

  final String label;
  final bool active;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

Color _statusColor(DispatchStatus status, Brightness brightness) => switch (status) {
  DispatchStatus.inTransit => AgriStatusColors.info(brightness),
  DispatchStatus.pendingPickup => AgriStatusColors.warning(brightness),
  DispatchStatus.delivered => AgriStatusColors.success(brightness),
  DispatchStatus.cancelled => AgriStatusColors.error(brightness),
};

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification, required this.colorScheme});

  final OrderNotification notification;
  final ColorScheme colorScheme;

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(notification.status, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  _initialsOf(notification.customerName),
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.customerName,
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16.5),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          notification.location,
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                child: Text(
                  notification.status.label,
                  style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: colorScheme.outline.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: notification.imageAsset != null
                      ? Image.asset(notification.imageAsset!, fit: BoxFit.cover)
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [colorScheme.primary.withValues(alpha: 0.35), colorScheme.primary.withValues(alpha: 0.12)],
                            ),
                          ),
                          child: Icon(Icons.eco_rounded, size: 24, color: colorScheme.primary.withValues(alpha: 0.8)),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.itemSummary,
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatGhs(notification.amount),
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Payment', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        notification.escrowStatus,
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (notification.status == DispatchStatus.inTransit || notification.status == DispatchStatus.pendingPickup) ...[
            const SizedBox(height: 14),
            if (notification.status == DispatchStatus.inTransit)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ComingSoonScreen(
                        title: 'Manage Dispatch',
                        icon: Icons.local_shipping_outlined,
                        message: 'Dispatch tracking and driver coordination will be available in a future update.',
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Manage Dispatch', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: () {
                    ref.read(orderNotificationsProvider.notifier).confirmPickup(notification.id);
                    showAgriToast(context, 'Pickup confirmed for ${notification.customerName}');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Confirm Pickup', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
