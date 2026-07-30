import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/dispatch_mock.dart';
import '../data/driver_profile_mock.dart';

String _initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

final driverStatusProvider = Provider<DriverStatusSummary>((ref) => mockDriverStatus);

/// Overlays the real signed-in user's name/initials onto the mock profile
/// so the Driver Home "Welcome back" header and Driver Profile screen never
/// disagree with what the driver actually signed up with.
final driverProfileProvider = Provider<DriverProfileSummary>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return mockDriverProfile;
  return DriverProfileSummary(
    name: user.name,
    initials: _initialsOf(user.name),
    badge: mockDriverProfile.badge,
    totalEarnings: mockDriverProfile.totalEarnings,
    completedJobs: mockDriverProfile.completedJobs,
    onlineHours: mockDriverProfile.onlineHours,
  );
});

final driverProfileDetailsProvider = Provider<DriverProfileDetails>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return mockDriverProfileDetails;
  return DriverProfileDetails(
    name: user.name,
    verified: mockDriverProfileDetails.verified,
    rating: mockDriverProfileDetails.rating,
    deliveriesCount: mockDriverProfileDetails.deliveriesCount,
    onTimePercent: mockDriverProfileDetails.onTimePercent,
    totalEarnings: mockDriverProfileDetails.totalEarnings,
    vehicle: mockDriverProfileDetails.vehicle,
    documents: mockDriverProfileDetails.documents,
  );
});

class DriverNotificationsController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final driverNotificationsProvider = NotifierProvider<DriverNotificationsController, bool>(
  DriverNotificationsController.new,
);

/// Availability toggle (checklist 2.2: "Driver: Home (Availability toggle)").
class DriverOnlineController extends Notifier<bool> {
  @override
  bool build() => mockDriverStatus.online;

  void toggle() => state = !state;
}

final driverOnlineProvider = NotifierProvider<DriverOnlineController, bool>(
  DriverOnlineController.new,
);

/// Nullable so "Complete Delivery" can clear it once the trip is done.
class ActiveTripController extends Notifier<ActiveTrip?> {
  @override
  ActiveTrip? build() => mockActiveTrip;

  void complete() => state = null;

  /// Accepting a job from the dispatch list makes it the driver's current
  /// active delivery — surfaced on both Driver Home and Driver Dispatch.
  void start(JobRequest job) {
    state = ActiveTrip(
      tripNumber: (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString(),
      etaMinutes: job.isShortHaul ? 12 : 25,
      destination: 'Deliver to ${job.dropoffLocation}',
      distanceRemainingKm: job.isShortHaul ? 2.4 : 8.5,
      job: job,
    );
  }
}

final activeTripProvider = NotifierProvider<ActiveTripController, ActiveTrip?>(
  ActiveTripController.new,
);

class JobFilterController extends Notifier<JobFilter> {
  @override
  JobFilter build() => JobFilter.all;

  void select(JobFilter filter) => state = filter;
}

final jobFilterProvider = NotifierProvider<JobFilterController, JobFilter>(
  JobFilterController.new,
);

/// Mutable so Accept/Decline actually remove the job from the list.
class AvailableJobsController extends Notifier<List<JobRequest>> {
  @override
  List<JobRequest> build() => List.of(mockJobRequests);

  void remove(String id) => state = state.where((job) => job.id != id).toList();
}

final availableJobsProvider = NotifierProvider<AvailableJobsController, List<JobRequest>>(
  AvailableJobsController.new,
);

final filteredJobsProvider = Provider<List<JobRequest>>((ref) {
  final filter = ref.watch(jobFilterProvider);
  final jobs = ref.watch(availableJobsProvider);
  return jobs.where((job) => switch (filter) {
    JobFilter.all => true,
    JobFilter.shortHaul => job.isShortHaul,
    JobFilter.highPayout => job.isHighPayout,
  }).toList();
});

final dispatchHistoryProvider = Provider<List<DispatchHistoryEntry>>((ref) => mockDispatchHistory);
