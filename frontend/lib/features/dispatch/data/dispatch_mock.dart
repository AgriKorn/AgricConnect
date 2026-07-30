/// Mock data standing in for the real Dispatch endpoints (available jobs,
/// active trip, driver online status, job history) until their backend
/// contracts are confirmed — same "build against a mock first" pattern used
/// throughout the checklist (see features/home/data).
class DriverStatusSummary {
  const DriverStatusSummary({required this.online, required this.jobsNearby});

  final bool online;
  final int jobsNearby;
}

const mockDriverStatus = DriverStatusSummary(online: true, jobsNearby: 4);

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

const mockDriverProfile = DriverProfileSummary(
  name: 'James',
  initials: 'JD',
  badge: 'Verified Gold Driver',
  totalEarnings: 1420,
  completedJobs: 8,
  onlineHours: 6.5,
);

class ActiveTrip {
  const ActiveTrip({
    required this.tripNumber,
    required this.etaMinutes,
    required this.destination,
    required this.distanceRemainingKm,
    required this.job,
  });

  final String tripNumber;
  final int etaMinutes;
  final String destination;
  final double distanceRemainingKm;

  /// The job request tied to this trip — Driver Home's "Active Delivery"
  /// preview shows it inline via the shared [JobRequestCard].
  final JobRequest job;
}

const mockActiveTrip = ActiveTrip(
  tripNumber: '8291',
  etaMinutes: 12,
  destination: 'Deliver to Makola Market',
  distanceRemainingKm: 2.4,
  job: JobRequest(
    id: 'active-j',
    cropSummary: '500kg Organic Tomatoes',
    pickupLocation: 'Green Valley Farm',
    dropoffLocation: 'Central Market Hub',
    timeRemaining: Duration(minutes: 12),
    payout: 450,
    isShortHaul: true,
    isHighPayout: true,
  ),
);

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
    required this.cropSummary,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.timeRemaining,
    required this.payout,
    required this.isShortHaul,
    required this.isHighPayout,
  });

  final String id;
  final String cropSummary;
  final String pickupLocation;
  final String dropoffLocation;
  final Duration timeRemaining;
  final double payout;
  final bool isShortHaul;
  final bool isHighPayout;
}

const mockJobRequests = [
  JobRequest(
    id: 'j1',
    cropSummary: '200kg Fresh Tomatoes',
    pickupLocation: 'Green Valley Farm, Aburi',
    dropoffLocation: 'Makola Market, Accra',
    timeRemaining: Duration(minutes: 2, seconds: 45),
    payout: 450,
    isShortHaul: true,
    isHighPayout: true,
  ),
  JobRequest(
    id: 'j2',
    cropSummary: '500kg Maize Bags',
    pickupLocation: 'Golden Grains Silo, Tema',
    dropoffLocation: 'Central Warehouse, Osu',
    timeRemaining: Duration(minutes: 5, seconds: 12),
    payout: 280,
    isShortHaul: false,
    isHighPayout: false,
  ),
];

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

const mockDispatchHistory = [
  DispatchHistoryEntry(id: 'h1', title: 'Sunrise Orchard Delivery', timestampLabel: 'Today, 09:15 AM', amount: 310),
  DispatchHistoryEntry(id: 'h2', title: 'AquaFish Logistics', timestampLabel: 'Yesterday', amount: 820),
];
