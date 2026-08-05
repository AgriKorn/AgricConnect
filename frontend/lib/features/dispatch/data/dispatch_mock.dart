/// Despite the file name, these are the real dispatch types — mapped from
/// GET /dispatch/jobs and the driver's own profile in dispatch_providers.dart.
class DriverStatusSummary {
  const DriverStatusSummary({required this.online, required this.jobsNearby});

  final bool online;
  final int jobsNearby;
}

class DriverProfileSummary {
  const DriverProfileSummary({
    required this.name,
    required this.initials,
    required this.badge,
    required this.totalEarnings,
    required this.completedJobs,
    required this.onlineHours,
  });

  final String name;
  final String initials;
  final String badge;
  final double totalEarnings;
  final int completedJobs;
  final double onlineHours;
}

class ActiveTrip {
  const ActiveTrip({
    required this.tripNumber,
    required this.destination,
    required this.job,
    required this.status,
    this.deliveryQrImage,
  });

  final String tripNumber;
  final String destination;

  /// The job request tied to this trip — Driver Home's "Active Delivery"
  /// preview shows it inline via the shared [JobRequestCard]. There is
  /// deliberately no ETA/distance-remaining field: no GPS or routing
  /// integration exists to back one, so this doesn't invent live-tracking
  /// numbers the way the old always-zero etaMinutes/distanceRemainingKm did.
  final JobRequest job;

  /// One of ACCEPTED, IN_TRANSIT, or DELIVERED — decides which action the
  /// trip card offers next: Mark Picked Up, Mark Delivered, or (once
  /// DELIVERED) the delivery QR for the buyer to scan.
  final String status;

  /// Data-URI QR image of the one-time delivery code, present only once
  /// [status] is DELIVERED.
  final String? deliveryQrImage;
}

enum JobFilter { all, shortHaul, highPayout }

extension JobFilterX on JobFilter {
  String get label => switch (this) {
    JobFilter.all => 'All Jobs',
    JobFilter.shortHaul => 'Short Haul',
    JobFilter.highPayout => 'High Payout',
  };
}

class JobRequest {
  const JobRequest({
    required this.id,
    required this.transactionId,
    required this.cropSummary,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.timeRemaining,
    required this.payout,
    required this.isShortHaul,
    required this.isHighPayout,
    this.farmerPhone,
    this.buyerPhone,
  });

  final String id;
  final String transactionId;
  final String cropSummary;
  final String pickupLocation;
  final String dropoffLocation;
  final Duration timeRemaining;
  final double payout;
  final bool isShortHaul;
  final bool isHighPayout;
  /// Real phone numbers for the pickup/dropoff contacts, if the backend has
  /// one on file — null shows no call/text affordance rather than a dead one.
  final String? farmerPhone;
  final String? buyerPhone;
}

class DispatchHistoryEntry {
  const DispatchHistoryEntry({
    required this.id,
    required this.title,
    required this.timestampLabel,
    required this.amount,
  });

  final String id;
  final String title;
  final String timestampLabel;
  final double amount;
}
