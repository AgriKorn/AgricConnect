import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models/account_status.dart';
import '../data/dispatch_mock.dart';
import '../data/dispatch_repository.dart';
import '../data/driver_profile_mock.dart';

/// Real data mapped onto the UI's [JobRequest] shape. Pickup/dropoff show the
/// real farmer/buyer name and region when the backend has them on file,
/// falling back to a deliberately generic label (never a fabricated address)
/// otherwise. [isShortHaul] has no real distance data either, so it's always
/// false; the "Short Haul" filter is a known no-op until real location
/// tracking exists.
JobRequest _toJobRequest(DispatchJobModel job) {
  final elapsed = DateTime.now().difference(job.createdAt);
  final pickup = job.farmerName != null
      ? [job.farmerName, job.pickupRegion].whereType<String>().join(', ')
      : 'Farm pickup (confirm on arrival)';
  final dropoff = job.buyerName != null
      ? [job.buyerName, job.dropoffRegion].whereType<String>().join(', ')
      : 'Buyer delivery (confirm on drop-off)';
  return JobRequest(
    id: job.id,
    transactionId: job.transactionId,
    cropSummary: '${job.quantityKg.toStringAsFixed(0)}kg ${job.cropType}',
    pickupLocation: pickup,
    dropoffLocation: dropoff,
    timeRemaining: elapsed,
    payout: job.amountGhs,
    isShortHaul: false,
    isHighPayout: job.amountGhs >= 300,
    farmerPhone: job.farmerPhone,
    buyerPhone: job.buyerPhone,
  );
}

String _initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
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

/// Real pending job offers for this driver — a genuine AsyncValue so the
/// dispatch screens can tell "no jobs right now" apart from "couldn't reach
/// the server" instead of collapsing both into an empty list.
class AvailableJobsController extends AsyncNotifier<List<JobRequest>> {
  @override
  Future<List<JobRequest>> build() => _fetch();

  Future<List<JobRequest>> _fetch() async {
    final jobs = await ref.read(dispatchRepositoryProvider).fetchJobs(status: 'PENDING');
    return jobs.map(_toJobRequest).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> accept(String jobId) async {
    await ref.read(dispatchRepositoryProvider).acceptJob(jobId);
    await refresh();
    await ref.read(activeTripProvider.notifier).refresh();
  }

  Future<void> decline(String jobId) async {
    await ref.read(dispatchRepositoryProvider).declineJob(jobId);
    await refresh();
  }
}

final availableJobsProvider = AsyncNotifierProvider<AvailableJobsController, List<JobRequest>>(
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
  final jobs = ref.watch(availableJobsProvider).valueOrNull ?? const [];
  return jobs.where((job) => switch (filter) {
    JobFilter.all => true,
    JobFilter.shortHaul => job.isShortHaul,
    JobFilter.highPayout => job.isHighPayout,
  }).toList();
});

/// The driver's one active (accepted, not yet completed) delivery, if any —
/// derived from real dispatch jobs rather than a separate mock concept.
/// ETA/distance aren't tracked by the backend, so the trip surfaces the same
/// real payout/crop/contact data as [JobRequest] without fabricating live
/// tracking. There is no driver-side "mark complete" action here — delivery
/// completion is the QR-based confirm-delivery flow (see job_history_screen
/// and confirm_delivery_screen), which either party (buyer or assigned
/// driver) can trigger; refresh() re-checks after that flow returns.
class ActiveTripController extends AsyncNotifier<ActiveTrip?> {
  @override
  Future<ActiveTrip?> build() => _fetch();

  Future<ActiveTrip?> _fetch() async {
    final jobs = await ref.read(dispatchRepositoryProvider).fetchJobs(status: 'ACCEPTED');
    if (jobs.isEmpty) return null;
    final job = jobs.first;
    return ActiveTrip(
      tripNumber: job.id.substring(0, job.id.length.clamp(0, 8)),
      destination: job.buyerName != null ? 'Deliver to ${job.buyerName}' : 'Deliver to buyer',
      job: _toJobRequest(job),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final activeTripProvider = AsyncNotifierProvider<ActiveTripController, ActiveTrip?>(
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

  return DriverProfileSummary(
    name: name,
    initials: _initialsOf(name),
    badge: 'AgriConnect Driver',
    totalEarnings: totalEarnings,
    completedJobs: history.length,
    onlineHours: 0,
  );
});

final driverStatusProvider = Provider<DriverStatusSummary>((ref) {
  final online = ref.watch(driverOnlineProvider);
  final jobsNearby = ref.watch(availableJobsProvider).valueOrNull?.length ?? 0;
  return DriverStatusSummary(online: online, jobsNearby: jobsNearby);
});

/// The deep Driver Profile screen's account-status and earnings/deliveries
/// figures are real, computed the same way as [driverProfileProvider].
/// Rating, on-time%, vehicle, and document verification have no backing
/// system in the backend at all — driver_profile_screen.dart routes those
/// sections to a "coming soon" state rather than this provider inventing
/// numbers for a feature that hasn't been built.
final driverProfileDetailsProvider = Provider<DriverProfileDetails>((ref) {
  final user = ref.watch(authControllerProvider).user;
  final history = ref.watch(dispatchHistoryProvider).valueOrNull ?? const [];
  final totalEarnings = history.fold<double>(0, (sum, entry) => sum + entry.amount);

  return DriverProfileDetails(
    name: user?.name ?? 'Driver',
    verified: user?.status == AccountStatus.verified,
    deliveriesCount: history.length,
    totalEarnings: totalEarnings,
  );
});

/// Real, persisted via PATCH /users/profile { notificationPreferences } — the
/// same field/mechanism the Buyer profile uses. There's no driver-specific
/// notification granularity on the backend, so this one toggle controls all
/// four flags together rather than only silently affecting one of them.
class DriverNotificationsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final profile = await ref.read(authRepositoryProvider).fetchProfile();
    return profile.orderStatusUpdates ?? true;
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? true;
    final next = !current;
    state = AsyncData(next);
    try {
      await ref.read(authRepositoryProvider).updateProfile({
        'notificationPreferences': {
          'orderStatusUpdates': next,
          'priceAlerts': next,
          'freshnessNotifications': next,
          'marketingOffers': next,
        },
      });
    } catch (_) {
      state = AsyncData(current);
    }
  }
}

final driverNotificationsProvider = AsyncNotifierProvider<DriverNotificationsController, bool>(
  DriverNotificationsController.new,
);
