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
    this.etaMinutes,
    this.driverName,
    this.driverRating,
    this.driverVehicle,
    this.transitProgress,
  });

  final String id;
  final String orderNumber;
  final String itemName;
  final BuyerOrderStatus status;
  final double escrowTotal;
  final String? farmerName;
  final String? farmerInitials;
  final String? farmerLocation;

  /// Live-tracking fields (Order Tracking screen) — only populated for
  /// shipments that are actually en route.
  final int? etaMinutes;
  final String? driverName;
  final double? driverRating;
  final String? driverVehicle;
  final double? transitProgress;
}

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
