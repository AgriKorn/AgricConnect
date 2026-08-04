import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/agri_toast.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../../orders/presentation/confirm_delivery_screen.dart';
import '../application/dispatch_providers.dart';
import '../data/dispatch_mock.dart';
import 'widgets/job_request_card.dart';

TextStyle _sectionTitleStyle(ColorScheme colorScheme) =>
    TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800);

/// Driver Dispatch: availability toggle -> active trip -> nearby job requests
/// (filterable, accept/decline) -> recent delivery history.
class DriverDispatchScreen extends ConsumerWidget {
  const DriverDispatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = ref.watch(driverStatusProvider);
    final online = ref.watch(driverOnlineProvider);
    final activeTripAsync = ref.watch(activeTripProvider);
    final filter = ref.watch(jobFilterProvider);
    final jobsAsync = ref.watch(availableJobsProvider);
    final jobs = ref.watch(filteredJobsProvider);
    final history = ref.watch(dispatchHistoryProvider).valueOrNull ?? const [];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: ResponsiveContent(
              child: RefreshIndicator(
              onRefresh: () => Future.wait([
                ref.read(availableJobsProvider.notifier).refresh(),
                ref.read(activeTripProvider.notifier).refresh(),
                ref.refresh(dispatchHistoryProvider.future),
              ]),
              child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _DriverHeader(
                  colorScheme: colorScheme,
                  online: online,
                  jobsNearby: status.jobsNearby,
                  onToggle: () => ref.read(driverOnlineProvider.notifier).toggle(),
                ),
                const SizedBox(height: 24),
                Text('Active Trip', style: _sectionTitleStyle(colorScheme)),
                const SizedBox(height: 12),
                activeTripAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => EmptyState(
                    icon: Icons.wifi_off_rounded,
                    message: 'Could not check your active trip. Pull to refresh, or tap Retry.',
                    ctaLabel: 'Retry',
                    onCta: () => ref.read(activeTripProvider.notifier).refresh(),
                  ),
                  data: (activeTrip) => activeTrip == null
                      ? _NoActiveTripCard(colorScheme: colorScheme)
                      : _ActiveTripCard(
                          trip: activeTrip,
                          colorScheme: colorScheme,
                          onConfirmDelivery: () async {
                            final result = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => ConfirmDeliveryScreen(transactionId: activeTrip.job.transactionId),
                              ),
                            );
                            if (result == true) {
                              await ref.read(activeTripProvider.notifier).refresh();
                              if (context.mounted) {
                                showAgriToast(context, 'Delivery confirmed — payment released to the farmer.');
                              }
                            }
                          },
                        ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Available Requests',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sectionTitleStyle(colorScheme),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ComingSoonScreen(
                            title: 'All Jobs',
                            icon: Icons.local_shipping_outlined,
                            message: 'A full list of nearby job requests will be available in a future update.',
                          ),
                        ),
                      ),
                      child: Text(
                        'See All',
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _JobFilterRow(
                  colorScheme: colorScheme,
                  selected: filter,
                  onSelect: (value) => ref.read(jobFilterProvider.notifier).select(value),
                ),
                const SizedBox(height: 14),
                if (jobsAsync.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (jobsAsync.hasError)
                  EmptyState(
                    icon: Icons.wifi_off_rounded,
                    message: 'Could not load job requests. Pull to refresh, or tap Retry.',
                    ctaLabel: 'Retry',
                    onCta: () => ref.read(availableJobsProvider.notifier).refresh(),
                  )
                else if (jobs.isEmpty)
                  EmptyState(
                    icon: Icons.local_shipping_outlined,
                    message: filter == JobFilter.all
                        ? 'No delivery requests are available nearby.'
                        : 'No jobs match this filter right now.',
                  )
                else
                  for (final job in jobs) ...[
                    JobRequestCard(
                      job: job,
                      colorScheme: colorScheme,
                      onDecline: () async {
                        try {
                          await ref.read(availableJobsProvider.notifier).decline(job.id);
                          if (context.mounted) {
                            showAgriToast(
                              context,
                              'Declined ${job.cropSummary}',
                              icon: Icons.cancel_rounded,
                              isError: true,
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            showAgriToast(context, 'Could not decline this job. Try again.', isError: true);
                          }
                        }
                      },
                      onAccept: () async {
                        try {
                          await ref.read(availableJobsProvider.notifier).accept(job.id);
                          if (context.mounted) showAgriToast(context, 'Accepted ${job.cropSummary}');
                        } catch (_) {
                          if (context.mounted) {
                            showAgriToast(context, 'Could not accept this job. Try again.', isError: true);
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                const SizedBox(height: 14),
                Text('Recent History', style: _sectionTitleStyle(colorScheme)),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  EmptyState(icon: Icons.history_rounded, message: 'No completed deliveries yet.')
                else
                  for (final entry in history) ...[
                    _HistoryRow(entry: entry, colorScheme: colorScheme),
                    const SizedBox(height: 12),
                  ],
              ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({
    required this.colorScheme,
    required this.online,
    required this.jobsNearby,
    required this.onToggle,
  });

  final ColorScheme colorScheme;
  final bool online;
  final int jobsNearby;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Driver Dispatch',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: online ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${online ? 'Online' : 'Offline'} • $jobsNearby jobs nearby',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: online, activeThumbColor: colorScheme.primary, onChanged: (_) => onToggle()),
            Text(
              online ? 'Active' : 'Inactive',
              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _NoActiveTripCard extends StatelessWidget {
  const _NoActiveTripCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: EmptyState(icon: Icons.local_shipping_outlined, message: 'No active trip right now.'),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip, required this.colorScheme, required this.onConfirmDelivery});

  final ActiveTrip trip;
  final ColorScheme colorScheme;
  final VoidCallback onConfirmDelivery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'In Progress • Trip #${trip.tripNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 56,
                  height: 56,
                  color: colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(Icons.map_rounded, color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.destination,
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onConfirmDelivery,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Confirm Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobFilterRow extends StatelessWidget {
  const _JobFilterRow({required this.colorScheme, required this.selected, required this.onSelect});

  final ColorScheme colorScheme;
  final JobFilter selected;
  final ValueChanged<JobFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in JobFilter.values) ...[
            _JobFilterChip(
              label: filter.label,
              active: filter == selected,
              colorScheme: colorScheme,
              onTap: () => onSelect(filter),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _JobFilterChip extends StatelessWidget {
  const _JobFilterChip({
    required this.label,
    required this.active,
    required this.colorScheme,
    required this.onTap,
  });

  final String label;
  final bool active;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? colorScheme.surfaceContainerHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.outline.withValues(alpha: active ? 0.5 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              Icon(Icons.check_rounded, size: 15, color: colorScheme.onSurface),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.colorScheme});

  final DispatchHistoryEntry entry;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.18), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(entry.timestampLabel, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatGhs(entry.amount),
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
        ],
      ),
    );
  }
}
