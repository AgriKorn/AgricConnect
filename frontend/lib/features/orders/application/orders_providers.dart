import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/orders_mock.dart';

enum OrdersTab { active, history, cancelled }

final ordersTabProvider = StateProvider<OrdersTab>((ref) => OrdersTab.active);

final activeShipmentsProvider = Provider<List<ActiveShipment>>((ref) => mockActiveShipments);

final orderHistoryProvider = Provider<List<OrderHistoryEntry>>((ref) => mockOrderHistory);

final cancelledOrdersProvider = Provider<List<OrderHistoryEntry>>((ref) => mockCancelledOrders);
