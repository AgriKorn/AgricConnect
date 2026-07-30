import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency.dart';
import '../../data/dispatch_mock.dart';

String formatCountdown(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Shared job-request card: used both on the Driver Dispatch list and inside
/// the Driver Home "Active Delivery" preview, so the two stay visually
/// identical instead of drifting into two hand-maintained copies.
class JobRequestCard extends StatelessWidget {
  const JobRequestCard({
    super.key,
    required this.job,
    required this.colorScheme,
    required this.onDecline,
    required this.onAccept,
  });

  final JobRequest job;
  final ColorScheme colorScheme;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final urgent = AgriStatusColors.error(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  job.cropSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: urgent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_rounded, size: 13, color: urgent),
                    const SizedBox(width: 4),
                    Text(
                      formatCountdown(job.timeRemaining),
                      style: TextStyle(color: urgent, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle)),
                  Container(width: 2, height: 30, color: colorScheme.outline.withValues(alpha: 0.3)),
                  Icon(Icons.location_on_rounded, size: 14, color: urgent),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PICKUP',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.pickupLocation,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'DROPOFF',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.dropoffLocation,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: colorScheme.outline.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAYOUT',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatGhs(job.payout),
                      style: TextStyle(color: colorScheme.primary, fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onDecline,
                child: Text('Decline', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700)),
              ),
              FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Accept Job', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
