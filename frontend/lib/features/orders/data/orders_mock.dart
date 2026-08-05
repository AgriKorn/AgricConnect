enum BuyerOrderStatus { awaitingDriver, driverAssigned, inTransit, awaitingConfirmation, completed, cancelled }

extension BuyerOrderStatusX on BuyerOrderStatus {
  String get label => switch (this) {
    BuyerOrderStatus.awaitingDriver => 'Awaiting Driver',
    BuyerOrderStatus.driverAssigned => 'Driver Assigned',
    BuyerOrderStatus.inTransit => 'In Transit',
    BuyerOrderStatus.awaitingConfirmation => 'Confirm Delivery',
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
    required this.hasOwnTransport,
    this.farmerId,
    this.farmerName,
    this.farmerInitials,
    this.farmerLocation,
    this.driverName,
    this.driverPhone,
  });

  final String id;
  final String orderNumber;
  final String itemName;
  final BuyerOrderStatus status;
  final double escrowTotal;
  /// True for self-collect orders — no driver is ever assigned to these.
  final bool hasOwnTransport;
  final String? farmerId;
  final String? farmerName;
  final String? farmerInitials;
  final String? farmerLocation;

  /// The driver who accepted this delivery — null until one has. There's no
  /// ETA, rating, or vehicle data anywhere in the system (no live GPS, no
  /// review system), so those aren't modeled here rather than faked.
  final String? driverName;
  final String? driverPhone;
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
