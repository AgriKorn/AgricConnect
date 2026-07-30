import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/dispatch_mock.dart';
import '../data/dispatch_repository.dart';
import '../data/driver_profile_mock.dart';

/// Real data mapped onto the UI's [JobRequest] shape. Pickup/dropoff have no
/// real address data behind them yet (the backend only tracks a listing's
/// region, not a geocoded pickup/dropoff pair) — deliberately generic labels
/// rather than fabricated-looking addresses. [isShortHaul] has no real
/// distance data either, so it's always false; the "Short Haul" filter is a
/// known no-op until real location tracking exists.
JobRequest _toJobRequest(DispatchJobModel job) {
  final elapsed = DateTime.now().difference(job.createdAt);
  return JobRequest(
    id: job.id,
    cropSummary: '${job.quantityKg.toStringAsFixed(0)}kg ${job.cropType}',
    pickupLocation: 'Farm pickup (confirm on arrival)',
    dropoffLocation: 'Buyer delivery (confirm on drop-off)',
    timeRemaining: elapsed,
    payout: job.amountGhs,
    isShortHaul: false,
    isHighPayout: job.amountGhs >= 300,
  );
}

/// Real driver online/offline availability — backed by the same
/// isAvailable flag the profile endpoint reads and writes.
class DriverOnlineController extends Notifier<bool> {
  @override
  bool build() {
    Future.microtask(_load);
    return true;
  }

  Future<void> _load() async {
    final available = await ref.read(dispatchRepositoryProvider).fetchIsAvailable();
    state = available;
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    try {
      await ref.read(dispatchRepositoryProvider).setAvailability(next);
    } catch (_) {
      state = !next;
    }
  }
}

final driverOnlineProvider = NotifierProvider<DriverOnlineController, bool>(
  DriverOnlineController.new,
);

/// Real pending job offers for this driver.
class AvailableJobsController extends Notifier<List<JobRequest>> {
  @override
  List<JobRequest> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final jobs = await ref.read(dispatchRepositoryProvider).fetchJobs(status: 'PENDING');
    state = jobs.map(_toJobRequest).toList();
  }

  Future<void> accept(String jobId) async {
    await ref.read(dispatchRepositoryProvider).acceptJob(jobId);
    await _load();
    ref.read(activeTripProvider.notifier).refresh();
  }

  Future<void> decline(String jobId) async {
    await ref.read(dispatchRepositoryProvider).declineJob(jobId);
    await _load();
  }
}

final availableJobsProvider = NotifierProvider<AvailableJobsController, List<JobRequest>>(
  AvailableJobsController.new,
);

class JobFilterController extends Notifier<JobFilter> {
  @override
  JobFilter build() => JobFilter.all;

  void select(JobFilter filter) => state = filter;
}

final jobFilterProvider = NotifierProvider<JobFilterController, JobFilter>(
  JobFilterController.new,
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

/// The driver's one active (accepted, not yet completed) delivery, if any —
/// derived from real dispatch jobs rather than a separate mock concept.
/// ETA/distance aren't tracked by the backend, so the trip surfaces the same
/// real payout/crop data as [JobRequest] without fabricating live tracking.
class ActiveTripController extends Notifier<ActiveTrip?> {
  @override
  ActiveTrip? build() {
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final jobs = await ref.read(dispatchRepositoryProvider).fetchJobs(status: 'ACCEPTED');
    if (jobs.isEmpty) {
      state = null;
      return;
    }
    final job = jobs.first;
    state = ActiveTrip(
      tripNumber: job.id.substring(0, job.id.length.clamp(0, 8)),
      etaMinutes: 0,
      destination: 'Deliver to buyer',
      distanceRemainingKm: 0,
      job: _toJobRequest(job),
    );
  }

  Future<void> complete() async {
    final current = state;
    if (current == null) return;
    await ref.read(dispatchRepositoryProvider).acceptJob(current.job.id);
    state = null;
  }
}

final activeTripProvider = NotifierProvider<ActiveTripController, ActiveTrip?>(
  ActiveTripController.new,
);

/// Completed jobs, real — powers both the history list and the earnings
/// summary on Driver Home so those numbers aren't invented.
final dispatchHistoryProvider = FutureProvider<List<DispatchHistoryEntry>>((ref) async {
  final jobs = await ref.read(dispatchRepositoryProvider).fetchJobs(status: 'COMPLETED');
  return jobs
      .map((job) => DispatchHistoryEntry(
            id: job.id,
            title: '${job.quantityKg.toStringAsFixed(0)}kg ${job.cropType}',
            timestampLabel: _relativeDay(job.createdAt),
            amount: job.amountGhs,
          ))
      .toList();
});

String _relativeDay(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inDays <= 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays} days ago';
}

/// Real name from the authenticated session; badge/onlineHours have no real
/// backend counterpart yet (no rating or hours-tracking system exists), so
/// they stay honestly generic rather than a fabricated "Verified Gold
/// Driver"-style claim. Earnings/completed count are real, computed from
/// [dispatchHistoryProvider].
final driverProfileProvider = Provider<DriverProfileSummary>((ref) {
  final name = ref.watch(authControllerProvider).user?.name ?? 'Driver';
  final history = ref.watch(dispatchHistoryProvider).valueOrNull ?? const [];
  final totalEarnings = history.fold<double>(0, (sum, entry) => sum + entry.amount);
  final initials = name.trim().isEmpty
      ? '?'
      : name.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase();

  return DriverProfileSummary(
    name: name,
    initials: initials,
    badge: 'AgriConnect Driver',
    totalEarnings: totalEarnings,
    completedJobs: history.length,
    onlineHours: 0,
  );
});

final driverStatusProvider = Provider<DriverStatusSummary>((ref) {
  final online = ref.watch(driverOnlineProvider);
  final jobsNearby = ref.watch(availableJobsProvider).length;
  return DriverStatusSummary(online: online, jobsNearby: jobsNearby);
});

/// The deep Driver Profile screen (rating, on-time%, verification documents,
/// vehicle) has no backing system yet — a rating/review engine and document
/// verification flow don't exist in the backend at all. Left on mock data
/// deliberately rather than fabricating numbers for a feature that hasn't
/// been built; only the actionable dispatch flow above (toggle, accept,
/// decline, earnings) is wired to real data.
final driverProfileDetailsProvider = Provider<DriverProfileDetails>((ref) => mockDriverProfileDetails);

class DriverNotificationsController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final driverNotificationsProvider = NotifierProvider<DriverNotificationsController, bool>(
  DriverNotificationsController.new,
);
