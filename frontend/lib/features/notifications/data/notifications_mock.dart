/// Mock data standing in for the real Orders/Dispatch notification feed
/// until its backend contract is confirmed — same "build against a mock
/// first" pattern used throughout the checklist.
enum DispatchStatus { inTransit, pendingPickup, delivered, cancelled }

extension DispatchStatusX on DispatchStatus {
  String get label => switch (this) {
    DispatchStatus.inTransit => 'In Transit',
    DispatchStatus.pendingPickup => 'Pending Pickup',
    DispatchStatus.delivered => 'Delivered',
    DispatchStatus.cancelled => 'Cancelled',
  };
}

class OrderNotification {
  const OrderNotification({
    required this.id,
    required this.customerName,
    required this.location,
    required this.status,
    required this.itemSummary,
    required this.amount,
    required this.escrowStatus,
    this.imageAsset,
  });

  final String id;
  final String customerName;
  final String location;
  final DispatchStatus status;
  final String itemSummary;
  final double amount;
  final String escrowStatus; // Escrowed | Released | Refunded
  final String? imageAsset;

  OrderNotification copyWith({DispatchStatus? status, String? escrowStatus}) {
    return OrderNotification(
      id: id,
      customerName: customerName,
      location: location,
      status: status ?? this.status,
      itemSummary: itemSummary,
      amount: amount,
      escrowStatus: escrowStatus ?? this.escrowStatus,
      imageAsset: imageAsset,
    );
  }
}

const mockOrderNotifications = [
  OrderNotification(
    id: 'o1',
    customerName: 'Emmanuel Kwesi',
    location: 'Accra Central',
    status: DispatchStatus.inTransit,
    itemSummary: '50kg Yellow Maize',
    amount: 450,
    escrowStatus: 'Escrowed',
    imageAsset: 'assets/images/yellow maize.png',
  ),
  OrderNotification(
    id: 'o2',
    customerName: 'Abena Appiah',
    location: 'Kumasi Market',
    status: DispatchStatus.pendingPickup,
    itemSummary: '12 Crates Organic Tomatoes',
    amount: 1200,
    escrowStatus: 'Escrowed',
    imageAsset: 'assets/images/roma tomatoes.png',
  ),
  OrderNotification(
    id: 'o3',
    customerName: 'Yaw Osei',
    location: 'Techiman',
    status: DispatchStatus.delivered,
    itemSummary: '30 Bags Cassava',
    amount: 540,
    escrowStatus: 'Released',
    imageAsset: 'assets/images/cassava.png',
  ),
  OrderNotification(
    id: 'o4',
    customerName: 'Efua Mensah',
    location: 'Sunyani',
    status: DispatchStatus.cancelled,
    itemSummary: '5kg Pepper',
    amount: 75,
    escrowStatus: 'Refunded',
    imageAsset: 'assets/images/belll pepper.png',
  ),
];
