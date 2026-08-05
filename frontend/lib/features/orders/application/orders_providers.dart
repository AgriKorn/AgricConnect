import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/orders_mock.dart';
import '../data/orders_repository.dart';

enum OrdersTab { active, history, cancelled }

final ordersTabProvider = StateProvider<OrdersTab>((ref) => OrdersTab.active);

/// Self-collect orders never get a driver — they sit in AWAITING_DRIVER
/// until the buyer scans the farmer's listing QR in person, so that raw
/// status means something different depending on [hasOwnTransport]: for a
/// self-collect order it's really "ready to confirm", not "waiting on
/// dispatch".
BuyerOrderStatus _statusFor(String rawStatus, bool hasOwnTransport) => switch (rawStatus) {
  'AWAITING_DRIVER' => hasOwnTransport ? BuyerOrderStatus.awaitingConfirmation : BuyerOrderStatus.awaitingDriver,
  'DRIVER_ASSIGNED' => BuyerOrderStatus.driverAssigned,
  'IN_TRANSIT' => BuyerOrderStatus.inTransit,
  'DELIVERED_PENDING_CONFIRMATION' => BuyerOrderStatus.awaitingConfirmation,
  'RELEASED' => BuyerOrderStatus.completed,
  'CANCELLED' => BuyerOrderStatus.cancelled,
  _ => BuyerOrderStatus.awaitingDriver,
};

String _initialsFor(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

String _deliveredLabelFor(OrderItemModel order) {
  final date = order.createdAt;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

final myOrdersProvider = FutureProvider<List<OrderItemModel>>((ref) {
  return ref.read(ordersRepositoryProvider).fetchUserOrders();
});

final activeShipmentsProvider = Provider<List<ActiveShipment>>((ref) {
  final orders = ref.watch(myOrdersProvider).valueOrNull ?? const [];
  return orders
      .where((o) => o.status != 'RELEASED' && o.status != 'CANCELLED')
      .map((o) => ActiveShipment(
            id: o.id,
            orderNumber: o.id.substring(0, o.id.length.clamp(0, 8)).toUpperCase(),
            itemName: o.listingName,
            status: _statusFor(o.status, o.hasOwnTransport),
            escrowTotal: o.amount,
            hasOwnTransport: o.hasOwnTransport,
            farmerId: o.farmerId,
            farmerName: o.farmerName,
            farmerInitials: o.farmerName == null ? null : _initialsFor(o.farmerName),
            driverName: o.driverName,
            driverPhone: o.driverPhone,
          ))
      .toList();
});

final orderHistoryProvider = Provider<List<OrderHistoryEntry>>((ref) {
  final orders = ref.watch(myOrdersProvider).valueOrNull ?? const [];
  return orders
      .where((o) => o.status == 'RELEASED')
      .map((o) => OrderHistoryEntry(
            id: o.id,
            itemName: o.listingName,
            deliveredLabel: 'Delivered ${_deliveredLabelFor(o)}',
            amount: o.amount,
            status: BuyerOrderStatus.completed,
          ))
      .toList();
});

final cancelledOrdersProvider = Provider<List<OrderHistoryEntry>>((ref) {
  final orders = ref.watch(myOrdersProvider).valueOrNull ?? const [];
  return orders
      .where((o) => o.status == 'CANCELLED')
      .map((o) => OrderHistoryEntry(
            id: o.id,
            itemName: o.listingName,
            deliveredLabel: _deliveredLabelFor(o),
            amount: o.amount,
            status: BuyerOrderStatus.cancelled,
          ))
      .toList();
});
