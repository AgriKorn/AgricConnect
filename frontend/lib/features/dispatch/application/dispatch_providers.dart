import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dispatch_mock.dart';
import '../data/driver_profile_mock.dart';

final driverStatusProvider = Provider<DriverStatusSummary>((ref) => mockDriverStatus);

final driverProfileProvider = Provider<DriverProfileSummary>((ref) => mockDriverProfile);

final driverProfileDetailsProvider = Provider<DriverProfileDetails>((ref) => mockDriverProfileDetails);

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
