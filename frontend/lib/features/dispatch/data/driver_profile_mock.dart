/// Despite the file name, this is the real Driver Profile shape — see
/// driverProfileDetailsProvider in dispatch_providers.dart. Rating, on-time%,
/// vehicle details, and document verification have no backing system in the
/// backend at all (no review/rating engine, no vehicle registration, no
/// document upload flow), so there is nothing to name here for them —
/// driver_profile_screen.dart routes those sections to a "coming soon" state
/// instead of inventing numbers.
class DriverProfileDetails {
  const DriverProfileDetails({
    required this.name,
    required this.verified,
    required this.deliveriesCount,
    required this.totalEarnings,
  });

  final String name;
  final bool verified;
  final int deliveriesCount;
  final double totalEarnings;
}
