/// Mock data standing in for the real Driver Profile endpoint until its
/// backend contract is confirmed — same "build against a mock first" pattern
/// used throughout the checklist (see features/home/data).
class DriverVehicle {
  const DriverVehicle({
    required this.model,
    required this.category,
    required this.capacityTons,
    required this.plateNumber,
  });

  final String model;
  final String category;
  final int capacityTons;
  final String plateNumber;
}

class DriverProfileDetails {
  const DriverProfileDetails({
    required this.name,
    required this.verified,
    required this.rating,
    required this.deliveriesCount,
    required this.onTimePercent,
    required this.totalEarnings,
    required this.vehicle,
    required this.documents,
  });

  final String name;
  final bool verified;
  final double rating;
  final int deliveriesCount;
  final int onTimePercent;
  final double totalEarnings;
  final DriverVehicle vehicle;
  final List<String> documents;
}

const mockDriverProfileDetails = DriverProfileDetails(
  name: 'Kofi Mensah',
  verified: true,
  rating: 4.8,
  deliveriesCount: 124,
  onTimePercent: 98,
  totalEarnings: 12450,
  vehicle: DriverVehicle(
    model: 'Mercedes-Benz Actros',
    category: 'Heavy Duty',
    capacityTons: 20,
    plateNumber: 'GT-482-22',
  ),
  documents: ["Driver's License", 'Vehicle Insurance', 'Road Worthiness'],
);
