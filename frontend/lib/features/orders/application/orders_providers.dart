import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/orders_mock.dart';
import '../data/orders_repository.dart';

enum OrdersTab { active, history, cancelled }

final ordersTabProvider = StateProvider<OrdersTab>((ref) => OrdersTab.active);

/// The backend only tracks a coarse PAYMENT_HELD/RELEASED/CANCELLED status
/// (not a finer in-transit/processing distinction), so every held order
/// maps to [BuyerOrderStatus.inTransit] rather than inventing a split the
/// data doesn't support.
BuyerOrderStatus _statusFor(String rawStatus) => switch (rawStatus) {
  'RELEASED' => BuyerOrderStatus.completed,
  'CANCELLED' => BuyerOrderStatus.cancelled,
  _ => BuyerOrderStatus.inTransit,
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
      .where((o) => o.status == 'PAYMENT_HELD')
      .map((o) => ActiveShipment(
            id: o.id,
            orderNumber: o.id.substring(0, o.id.length.clamp(0, 8)).toUpperCase(),
            itemName: o.listingName,
            status: _statusFor(o.status),
            escrowTotal: o.amount,
            hasOwnTransport: o.hasOwnTransport,
            farmerName: o.farmerName,
            farmerInitials: o.farmerName == null ? null : _initialsFor(o.farmerName),
            driverName: o.driverName,
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
