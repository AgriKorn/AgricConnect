import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/dispatch_providers.dart';
import '../data/dispatch_mock.dart';
import 'widgets/job_request_card.dart';

void _pushComingSoon(BuildContext context, {required String title, required IconData icon, required String message}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (context) => ComingSoonScreen(title: title, icon: icon, message: message)),
  );
}

/// Driver Home: profile hero + earnings/online snapshot -> availability
/// toggle -> active delivery preview (map, job details, accept/decline,
/// navigate) -> quick-access logistics tools.
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(driverProfileProvider);
    final online = ref.watch(driverOnlineProvider);
    final activeTrip = ref.watch(activeTripProvider);

    return Scaffold(
      body: SafeArea(
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
                          'Active Delivery',
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
                  activeTrip == null
                      ? _NoActiveDeliveryCard(colorScheme: colorScheme)
                      : _ActiveDeliveryCard(
                          trip: activeTrip,
                          colorScheme: colorScheme,
                          onDecline: () {
                            ref.read(activeTripProvider.notifier).complete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Declined ${activeTrip.job.cropSummary}')),
                            );
                          },
                          onAccept: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Accepted ${activeTrip.job.cropSummary}')),
                            );
                          },
                          onOpenNavigation: () => _pushComingSoon(
                            context,
                            title: 'Navigation',
                            icon: Icons.navigation_rounded,
                            message: 'Turn-by-turn navigation will be available in a future update.',
                          ),
                        ),
                  const SizedBox(height: 28),
                  Text(
                    'Logistics Tools',
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  _LogisticsToolsGrid(colorScheme: colorScheme),
                ],
              ),
            ),
          ],
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
                  onPressed: () => _pushComingSoon(
                    context,
                    title: 'Notifications',
                    icon: Icons.notifications_none_rounded,
                    message: 'Driver notifications will be available in a future update.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatPill(
                  colorScheme: colorScheme,
                  dotColor: colorScheme.onPrimary.withValues(alpha: 0.7),
                  value: formatGhs(profile.totalEarnings),
                  label: 'Earnings',
                ),
                const SizedBox(width: 10),
                _StatPill(
                  colorScheme: colorScheme,
                  dotColor: colorScheme.onPrimary.withValues(alpha: 0.7),
                  value: '${profile.completedJobs}',
                  label: 'Completed',
                ),
                const SizedBox(width: 10),
                _StatPill(
                  colorScheme: colorScheme,
                  dotColor: AgriStatusColors.warning(Theme.of(context).brightness),
                  value: '${profile.onlineHours}h',
                  label: 'Online',
                  highlighted: online,
                ),
              ],
            ),
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
    this.highlighted = false,
  });

  final ColorScheme colorScheme;
  final Color dotColor;
  final String value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: highlighted ? Border.all(color: dotColor, width: 1.5) : null,
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

class _NoActiveDeliveryCard extends StatelessWidget {
  const _NoActiveDeliveryCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: EmptyState(icon: Icons.local_shipping_outlined, message: 'No active delivery right now.'),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({
    required this.trip,
    required this.colorScheme,
    required this.onDecline,
    required this.onAccept,
    required this.onOpenNavigation,
  });

  final ActiveTrip trip;
  final ColorScheme colorScheme;
  final VoidCallback onDecline;
  final VoidCallback onAccept;
  final VoidCallback onOpenNavigation;

  @override
  Widget build(BuildContext context) {
    final warning = AgriStatusColors.warning(Theme.of(context).brightness);
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(999)),
                      child: const Text(
                        'IN TRANSIT',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'ETA: ${trip.etaMinutes} mins',
                      style: TextStyle(color: warning, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                JobRequestCard(job: trip.job, colorScheme: colorScheme, onDecline: onDecline, onAccept: onAccept),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: onOpenNavigation,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Open Navigation', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogisticsToolsGrid extends StatelessWidget {
  const _LogisticsToolsGrid({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final warning = AgriStatusColors.warning(Theme.of(context).brightness);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.5,
      children: [
        _ToolTile(
          colorScheme: colorScheme,
          icon: Icons.history_rounded,
          label: 'Job History',
          onTap: () => context.go('/driver/history'),
        ),
        _ToolTile(
          colorScheme: colorScheme,
          icon: Icons.local_gas_station_rounded,
          label: 'Fuel Log',
          accent: colorScheme.tertiary,
          onTap: () => _pushComingSoon(
            context,
            title: 'Fuel Log',
            icon: Icons.local_gas_station_rounded,
            message: 'Fuel expense tracking will be available in a future update.',
          ),
        ),
        _ToolTile(
          colorScheme: colorScheme,
          icon: Icons.local_shipping_outlined,
          label: 'Vehicle',
          onTap: () => _pushComingSoon(
            context,
            title: 'Vehicle',
            icon: Icons.local_shipping_outlined,
            message: 'Vehicle details and maintenance logs will be available in a future update.',
          ),
        ),
        _ToolTile(
          colorScheme: colorScheme,
          icon: Icons.warning_amber_rounded,
          label: 'Report Delay',
          accent: warning,
          emphasized: true,
          onTap: () => _pushComingSoon(
            context,
            title: 'Report Delay',
            icon: Icons.warning_amber_rounded,
            message: 'Delay reporting will be available in a future update.',
          ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.colorScheme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
    this.emphasized = false,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (accent ?? colorScheme.outline).withValues(alpha: emphasized ? 0.5 : 0.2)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: emphasized ? tint : colorScheme.onSurfaceVariant, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: emphasized ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
