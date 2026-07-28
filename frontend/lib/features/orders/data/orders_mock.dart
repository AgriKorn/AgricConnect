/// Mock data standing in for the real buyer Orders/Escrow endpoint until its
/// backend contract is confirmed — same "build against a mock first"
/// pattern used throughout the checklist (see features/home/data).
enum BuyerOrderStatus { inTransit, processing, completed, cancelled }

extension BuyerOrderStatusX on BuyerOrderStatus {
  String get label => switch (this) {
    BuyerOrderStatus.inTransit => 'In Transit',
    BuyerOrderStatus.processing => 'Processing',
    BuyerOrderStatus.completed => 'Completed',
    BuyerOrderStatus.cancelled => 'Cancelled',
  };
}

class ActiveShipment {
  const ActiveShipment({
    required this.id,
    required this.orderNumber,
    required this.itemName,
    required this.status,
    required this.escrowTotal,
    this.farmerName,
    this.farmerInitials,
    this.farmerLocation,
  });

  final String id;
  final String orderNumber;
  final String itemName;
  final BuyerOrderStatus status;
  final double escrowTotal;
  final String? farmerName;
  final String? farmerInitials;
  final String? farmerLocation;
}

const mockActiveShipments = [
  ActiveShipment(
    id: 'o1',
    orderNumber: 'AGR-8821',
    itemName: 'Fresh Organic Tomatoes',
    status: BuyerOrderStatus.inTransit,
    escrowTotal: 450,
    farmerName: 'Kofi Mensah',
    farmerInitials: 'KW',
    farmerLocation: 'Kumasi Central Farm • 12km away',
  ),
  ActiveShipment(
    id: 'o2',
    orderNumber: 'AGR-7902',
    itemName: 'Sweet Yellow Maize',
    status: BuyerOrderStatus.processing,
    escrowTotal: 1200,
  ),
];

class OrderHistoryEntry {
  const OrderHistoryEntry({
    required this.id,
    required this.itemName,
    required this.deliveredLabel,
    required this.amount,
    required this.status,
  });

  final String id;
  final String itemName;
  final String deliveredLabel;
  final double amount;
  final BuyerOrderStatus status;
}

const mockOrderHistory = [
  OrderHistoryEntry(
    id: 'h1',
    itemName: 'Premium Arabica Coffee',
    deliveredLabel: 'Delivered Oct 12 • 5.0kg',
    amount: 85,
    status: BuyerOrderStatus.completed,
  ),
];

const List<OrderHistoryEntry> mockCancelledOrders = [];
