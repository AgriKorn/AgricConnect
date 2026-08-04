import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../application/orders_providers.dart';
import '../data/orders_repository.dart';

(String, Color) _statusStyle(String rawStatus, Brightness brightness) => switch (rawStatus) {
  'RELEASED' => ('Paid Out', AgriStatusColors.success(brightness)),
  'CANCELLED' => ('Cancelled', AgriStatusColors.error(brightness)),
  _ => ('Awaiting Delivery', AgriStatusColors.info(brightness)),
};

/// Farmer's read-only sales list — the same GET /transactions data buyers
/// see their purchases in (myOrdersProvider), but every transaction here has
/// the signed-in farmer on the selling side, so it's shown with the buyer's
/// name instead. Confirm-delivery / dispute actions are buyer-or-driver-only
/// server-side, so this screen has no action buttons, just status.
class FarmerSalesScreen extends ConsumerWidget {
  const FarmerSalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ordersAsync = ref.watch(myOrdersProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: ResponsiveContent(
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.chevron_left_rounded, color: colorScheme.onSurface),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          shape: const CircleBorder(),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'My Sales',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => ref.refresh(myOrdersProvider.future),
                    child: ordersAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => ListView(
                        children: [
                          const SizedBox(height: 60),
                          EmptyState(
                            icon: Icons.wifi_off_rounded,
                            message: 'Could not load your sales. Pull down to retry.',
                          ),
                        ],
                      ),
                      data: (orders) => orders.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 60),
                                EmptyState(
                                  icon: Icons.point_of_sale_outlined,
                                  message: 'No sales yet — they\'ll show up here as buyers purchase your listings.',
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                              itemCount: orders.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) =>
                                  _SaleRow(colorScheme: colorScheme, order: orders[index]),
                            ),
                    ),
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

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.colorScheme, required this.order});

  final ColorScheme colorScheme;
  final OrderItemModel order;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _statusStyle(order.status, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(16),
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
                  order.listingName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  order.buyerName != null ? 'Sold to ${order.buyerName}' : 'Buyer details unavailable',
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
                formatGhs(order.amount),
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
                  statusLabel,
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
