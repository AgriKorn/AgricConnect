import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications_mock.dart';

/// Mutable so "Confirm Pickup" can actually move an order from Pending
/// Pickup to In Transit — not just a static mock list.
class OrderNotificationsController extends Notifier<List<OrderNotification>> {
  @override
  List<OrderNotification> build() => List.of(mockOrderNotifications);

  void confirmPickup(String id) {
    state = [
      for (final notification in state)
        if (notification.id == id)
          notification.copyWith(status: DispatchStatus.inTransit)
        else
          notification,
    ];
  }
}

final orderNotificationsProvider =
    NotifierProvider<OrderNotificationsController, List<OrderNotification>>(
  OrderNotificationsController.new,
);
