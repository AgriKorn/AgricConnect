import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/agri_toast.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_content.dart';
import '../application/dispatch_providers.dart';
import '../data/dispatch_mock.dart';
import 'widgets/job_request_card.dart';

void _pushComingSoon(BuildContext context, {required String title, required IconData icon, required String message}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (context) => ComingSoonScreen(title: title, icon: icon, message: message)),
  );
}

/// Driver Home: profile hero + earnings/online snapshot -> availability
/// toggle -> active trip preview (map, job details, accept/decline,
/// navigate) -> quick-access logistics tools.
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(driverProfileProvider);
    final online = ref.watch(driverOnlineProvider);
    final activeTripAsync = ref.watch(activeTripProvider);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContent(
          child: RefreshIndicator(
          onRefresh: () => ref.read(activeTripProvider.notifier).refresh(),
          child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HeroHeader(colorScheme: colorScheme, profile: profile, online: online),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusCard(
                    colorScheme: colorScheme,
                    online: online,
                    onToggle: () => ref.read(driverOnlineProvider.notifier).toggle(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Active Trip',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _pushComingSoon(
                          context,
                          title: 'Route Details',
                          icon: Icons.route_rounded,
                          message: 'Turn-by-turn route details will be available in a future update.',
                        ),
                        child: Text(
                          'Route Details',
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
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
                            onMarkPickedUp: () async {
                              try {
                                await ref.read(activeTripProvider.notifier).markPickedUp(activeTrip.job.id);
                                if (context.mounted) showAgriToast(context, 'Marked as picked up.');
                              } catch (_) {
                                if (context.mounted) {
                                  showAgriToast(context, 'Could not update this trip. Try again.', isError: true);
                                }
                              }
                            },
                            onMarkDelivered: () async {
                              try {
                                await ref.read(activeTripProvider.notifier).markDelivered(activeTrip.job.id);
                                if (context.mounted) {
                                  showAgriToast(context, 'Show the QR code to the buyer to release payment.');
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  showAgriToast(context, 'Could not update this trip. Try again.', isError: true);
                                }
                              }
                            },
                            onOpenNavigation: () => _pushComingSoon(
                              context,
                              title: 'Navigation',
                              icon: Icons.navigation_rounded,
                              message: 'Turn-by-turn navigation will be available in a future update.',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
          ),
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.colorScheme, required this.profile, required this.online});

  final ColorScheme colorScheme;
  final DriverProfileSummary profile;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/driver/profile'),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
                  child: Text(
                    profile.initials,
                    style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${profile.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onPrimary, fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.badge,
                      style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.85), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colorScheme.onPrimary.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Notifications',
                  icon: Icon(Icons.notifications_none_rounded, color: colorScheme.onPrimary, size: 20),
                  onPressed: () => context.go('/driver/alerts'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatPill(
                colorScheme: colorScheme,
                dotColor: colorScheme.onPrimary.withValues(alpha: 0.7),
                value: formatGhs(profile.totalEarnings),
                label: 'Earnings',
                width: 168,
              ),
              _StatPill(
                colorScheme: colorScheme,
                dotColor: colorScheme.onPrimary.withValues(alpha: 0.7),
                value: '${profile.completedJobs}',
                label: 'Completed',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.colorScheme,
    required this.dotColor,
    required this.value,
    required this.label,
    this.width = 128,
  });

  final ColorScheme colorScheme;
  final Color dotColor;
  final String value;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.colorScheme, required this.online, required this.onToggle});

  final ColorScheme colorScheme;
  final bool online;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${online ? 'Online' : 'Offline'}',
                  style: TextStyle(
                    color: online ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Visible to nearby shippers',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Switch(value: online, activeThumbColor: colorScheme.primary, onChanged: (_) => onToggle()),
        ],
      ),
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
  const _ActiveTripCard({
    required this.trip,
    required this.colorScheme,
    required this.onMarkPickedUp,
    required this.onMarkDelivered,
    required this.onOpenNavigation,
  });

  final ActiveTrip trip;
  final ColorScheme colorScheme;
  final VoidCallback onMarkPickedUp;
  final VoidCallback onMarkDelivered;
  final VoidCallback onOpenNavigation;

  @override
  Widget build(BuildContext context) {
    final delivered = trip.status == 'DELIVERED';
    final statusLabel = switch (trip.status) {
      'IN_TRANSIT' => 'IN TRANSIT',
      'DELIVERED' => 'AWAITING BUYER SCAN',
      _ => 'PICKUP PENDING',
    };

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            child: Container(
              height: 150,
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(Icons.map_rounded, size: 40, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 14),
                JobRequestCard(job: trip.job, colorScheme: colorScheme),
                const SizedBox(height: 14),
                if (delivered)
                  _DeliveryQrPanel(colorScheme: colorScheme, qrImage: trip.deliveryQrImage)
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOpenNavigation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text('Navigate', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: trip.status == 'IN_TRANSIT' ? onMarkDelivered : onMarkPickedUp,
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(trip.status == 'IN_TRANSIT' ? Icons.flag_rounded : Icons.inventory_2_rounded, size: 18),
                          label: Text(
                            trip.status == 'IN_TRANSIT' ? 'Delivered' : 'Picked Up',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryQrPanel extends StatelessWidget {
  const _DeliveryQrPanel({required this.colorScheme, required this.qrImage});

  final ColorScheme colorScheme;
  final String? qrImage;

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes;
    final data = qrImage;
    if (data != null && data.startsWith('data:image')) {
      try {
        imageBytes = base64Decode(data.split(',').last);
      } catch (_) {
        imageBytes = null;
      }
    }

    return Column(
      children: [
        Text(
          'Show this to the buyer to release payment',
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: imageBytes != null
              ? Image.memory(imageBytes, width: 180, height: 180)
              : const SizedBox(
                  width: 180,
                  height: 180,
                  child: Center(child: Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.black26)),
                ),
        ),
      ],
    );
  }
}

