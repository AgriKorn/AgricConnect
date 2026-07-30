import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/orders_providers.dart';
import '../data/orders_mock.dart';
import 'confirm_delivery_screen.dart';
import 'raise_dispute_screen.dart';

void _openComingSoon(BuildContext context, String title, IconData icon) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ComingSoonScreen(
        title: title,
        icon: icon,
        message: '$title will be available in a future update.',
      ),
    ),
  );
}

(Color, Color, IconData) _statusStyle(BuyerOrderStatus status, Brightness brightness) => switch (status) {
  BuyerOrderStatus.inTransit => (AgriStatusColors.info(brightness), AgriStatusColors.onInfo(brightness), Icons.local_shipping_rounded),
  BuyerOrderStatus.processing => (AgriStatusColors.warning(brightness), AgriStatusColors.onWarning(brightness), Icons.autorenew_rounded),
  BuyerOrderStatus.completed => (AgriStatusColors.success(brightness), AgriStatusColors.onSuccess(brightness), Icons.check_circle_rounded),
  BuyerOrderStatus.cancelled => (AgriStatusColors.error(brightness), AgriStatusColors.onError(brightness), Icons.cancel_rounded),
};

/// Buyer Orders: Active/History/Cancelled tabs -> Active Shipments (real
/// escrow tracking, confirm delivery / raise a dispute) -> Recent History.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  Future<void> _confirmDelivery(BuildContext context, WidgetRef ref, String orderId) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ConfirmDeliveryScreen(transactionId: orderId)),
    );
    if (result == true) {
      ref.invalidate(myOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery confirmed — payment released to the farmer.')),
        );
      }
    }
  }

  Future<void> _reportProblem(BuildContext context, WidgetRef ref, String orderId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RaiseDisputeScreen(transactionId: orderId)),
    );
    ref.invalidate(myOrdersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final tab = ref.watch(ordersTabProvider);
    final activeShipments = ref.watch(activeShipmentsProvider);
    final history = ref.watch(orderHistoryProvider);
    final cancelled = ref.watch(cancelledOrdersProvider);
    final loading = ref.watch(myOrdersProvider).isLoading;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(myOrdersProvider.future),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Orders',
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Track your farm-fresh produce',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: _OrderTabs(
                      colorScheme: colorScheme,
                      selected: tab,
                      onSelect: (value) => ref.read(ordersTabProvider.notifier).state = value,
                    ),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                            children: switch (tab) {
                              OrdersTab.active => [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Active Shipments',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${activeShipments.length}',
                                        style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (activeShipments.isEmpty)
                                  EmptyState(icon: Icons.local_shipping_outlined, message: 'No active shipments right now.')
                                else
                                  for (final shipment in activeShipments) ...[
                                    _ActiveShipmentCard(
                                      colorScheme: colorScheme,
                                      shipment: shipment,
                                      onConfirmDelivery: () => _confirmDelivery(context, ref, shipment.id),
                                      onReportProblem: () => _reportProblem(context, ref, shipment.id),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                const SizedBox(height: 14),
                                Text(
                                  'Recent History',
                                  style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 14),
                                if (history.isEmpty)
                                  EmptyState(icon: Icons.history_rounded, message: 'No completed orders yet.')
                                else
                                  for (final entry in history) ...[
                                    _HistoryRow(colorScheme: colorScheme, entry: entry),
                                    const SizedBox(height: 12),
                                  ],
                              ],
                              OrdersTab.history => [
                                if (history.isEmpty)
                                  EmptyState(icon: Icons.history_rounded, message: 'No completed orders yet.')
                                else
                                  for (final entry in history) ...[
                                    _HistoryRow(colorScheme: colorScheme, entry: entry),
                                    const SizedBox(height: 12),
                                  ],
                              ],
                              OrdersTab.cancelled => [
                                if (cancelled.isEmpty)
                                  EmptyState(icon: Icons.cancel_outlined, message: 'No cancelled orders.')
                                else
                                  for (final entry in cancelled) ...[
                                    _HistoryRow(colorScheme: colorScheme, entry: entry),
                                    const SizedBox(height: 12),
                                  ],
                              ],
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTabs extends StatelessWidget {
  const _OrderTabs({required this.colorScheme, required this.selected, required this.onSelect});

  final ColorScheme colorScheme;
  final OrdersTab selected;
  final ValueChanged<OrdersTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final tab in OrdersTab.values)
            Expanded(
              child: _OrderTab(
                label: switch (tab) {
                  OrdersTab.active => 'Active',
                  OrdersTab.history => 'History',
                  OrdersTab.cancelled => 'Cancelled',
                },
                active: tab == selected,
                colorScheme: colorScheme,
                onTap: () => onSelect(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderTab extends StatelessWidget {
  const _OrderTab({required this.label, required this.active, required this.colorScheme, required this.onTap});

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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.colorScheme});

  final BuyerOrderStatus status;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _statusStyle(status, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: bg),
          const SizedBox(width: 6),
          Text(status.label, style: TextStyle(color: bg, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ActiveShipmentCard extends StatelessWidget {
  const _ActiveShipmentCard({
    required this.colorScheme,
    required this.shipment,
    required this.onConfirmDelivery,
    required this.onReportProblem,
  });

  final ColorScheme colorScheme;
  final ActiveShipment shipment;
  final VoidCallback onConfirmDelivery;
  final VoidCallback onReportProblem;

  @override
  Widget build(BuildContext context) {
    final hasFarmer = shipment.farmerName != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${shipment.orderNumber}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shipment.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: shipment.status, colorScheme: colorScheme),
            ],
          ),
          if (hasFarmer) ...[
            const SizedBox(height: 16),
            Divider(color: colorScheme.outline.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    shipment.farmerInitials ?? '?',
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    shipment.farmerName!,
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openComingSoon(context, 'Chat', Icons.chat_bubble_outline_rounded),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, color: colorScheme.primary, size: 18),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Escrow Total',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            formatGhs(shipment.escrowTotal),
            style: TextStyle(color: colorScheme.primary, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReportProblem,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Report a Problem'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirmDelivery,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Confirm Delivery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.colorScheme, required this.entry});

  final ColorScheme colorScheme;
  final OrderHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final (statusColor, _, _) = _statusStyle(entry.status, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.inventory_2_outlined, color: colorScheme.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.deliveredLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatGhs(entry.amount),
                style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  entry.status.label,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
