import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/orders_repository.dart';
import 'confirm_delivery_screen.dart';
import 'raise_dispute_screen.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool _loading = true;
  List<OrderItemModel> _orders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await ref.read(ordersRepositoryProvider).fetchUserOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _confirmDelivery(OrderItemModel order) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ConfirmDeliveryScreen(transactionId: order.id)),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery confirmed — payment released to the farmer.')),
      );
      _load();
    }
  }

  Future<void> _reportProblem(OrderItemModel order) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RaiseDisputeScreen(transactionId: order.id)),
    );
    if (mounted) _load();
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
                  : _orders.isEmpty
                      ? ListView(
                          children: const [
                            EmptyState(
                              icon: Icons.receipt_long_outlined,
                              message: 'Your orders and escrow status will appear here.',
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          children: [
                            Text(
                              'My Orders',
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 18),
                            ..._orders.map((order) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _OrderCard(
                                    order: order,
                                    colorScheme: colorScheme,
                                    onConfirmDelivery: () => _confirmDelivery(order),
                                    onReportProblem: () => _reportProblem(order),
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

(Color, String) _statusPresentation(ColorScheme colorScheme, String status) => switch (status) {
  'RELEASED' => (colorScheme.primary, 'Delivered · Paid'),
  'CANCELLED' => (colorScheme.error, 'Cancelled'),
  _ => (colorScheme.tertiary, 'Awaiting Delivery'),
};

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.colorScheme,
    required this.onConfirmDelivery,
    required this.onReportProblem,
  });

  final OrderItemModel order;
  final ColorScheme colorScheme;
  final VoidCallback onConfirmDelivery;
  final VoidCallback onReportProblem;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = _statusPresentation(colorScheme, order.status);
    final isPending = order.status == 'PAYMENT_HELD';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.listingName,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatGhs(order.amount),
            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          if (isPending) ...[
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
                    ),
                    child: const Text('Confirm Delivery'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
