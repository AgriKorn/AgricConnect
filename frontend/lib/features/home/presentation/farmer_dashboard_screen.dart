import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../application/farmer_dashboard_providers.dart';
import '../data/farmer_dashboard_mock.dart';

const _heroImage = 'assets/images/farmer_hero.jpeg';

/// Farmer Home: greeting header -> Market trend banner -> Scan CTA ->
/// Active Listings carousel -> Overview stats grid.
class FarmerDashboardScreen extends ConsumerWidget {
  const FarmerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = ref.watch(farmerDashboardSummaryProvider);
    final listingsAsync = ref.watch(farmerListingsProvider);
    final listings = listingsAsync.valueOrNull?.where((listing) => listing.status == 'Active').toList() ?? const [];
    final alertCount = ref.watch(freshnessAlertsProvider).length;
    final rawName = ref.watch(authControllerProvider).user?.name.trim();
    final firstName = (rawName != null && rawName.isNotEmpty) ? rawName.split(RegExp(r'\s+')).first : 'Farmer';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _DashboardHeader(
                  colorScheme: colorScheme,
                  name: firstName,
                  summary: summary,
                  onBell: () => context.go('/farmer/alerts'),
                ),
                const SizedBox(height: 20),
                _MarketTrendCard(colorScheme: colorScheme, summary: summary),
                const SizedBox(height: 20),
                _ScanCard(colorScheme: colorScheme, onScan: () => context.go('/farmer/scan')),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Active Listings',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/farmer/listings'),
                      child: Text(
                        'See All',
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: listingsAsync.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : listings.isEmpty
                      ? EmptyState(
                          icon: Icons.grass_outlined,
                          message: 'You have no active listings yet.',
                          ctaLabel: 'Scan produce',
                          onCta: () => context.go('/farmer/scan'),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: listings.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 14),
                          itemBuilder: (context, index) => _ListingCard(listing: listings[index], colorScheme: colorScheme),
                        ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Overview',
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _OverviewGrid(colorScheme: colorScheme, summary: summary, alertCount: alertCount),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _greetingForNow() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.colorScheme,
    required this.name,
    required this.summary,
    required this.onBell,
  });

  final ColorScheme colorScheme;
  final String name;
  final FarmerDashboardSummary summary;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipOval(
          child: Image.asset(_heroImage, width: 52, height: 52, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greetingForNow()}, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(summary.weatherIcon, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${summary.weatherTempC}°C · ${summary.location}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'Notifications',
            icon: Icon(Icons.notifications_none_rounded, color: colorScheme.onSurface, size: 20),
            onPressed: onBell,
          ),
        ),
      ],
    );
  }
}

class _MarketTrendCard extends StatelessWidget {
  const _MarketTrendCard({required this.colorScheme, required this.summary});

  final ColorScheme colorScheme;
  final FarmerDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final isUp = summary.marketTrendPercent >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.tertiary],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Market is ${isUp ? 'Up' : 'Down'}',
                  style: TextStyle(color: colorScheme.onPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${isUp ? '+' : ''}${summary.marketTrendPercent.toStringAsFixed(1)}% Today',
                  style: TextStyle(color: colorScheme.onPrimary, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Market Trends',
                      style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: colorScheme.onPrimary, size: 15),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: colorScheme.onPrimary,
            size: 30,
          ),
        ],
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.colorScheme, required this.onScan});

  final ColorScheme colorScheme;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.18),
              boxShadow: [
                BoxShadow(color: colorScheme.primary.withValues(alpha: 0.45), blurRadius: 30, spreadRadius: 4),
              ],
            ),
            child: Icon(Icons.center_focus_strong_rounded, color: colorScheme.primary, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            'Scan Your Harvest',
            style: TextStyle(color: colorScheme.onSurface, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'AI-powered freshness & price analysis',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onScan,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: const StadiumBorder(),
              ),
              child: const Text('Start Scanning', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.colorScheme});

  final FarmerListingSummary listing;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final freshness = freshnessColorFor(listing.freshnessScore, Theme.of(context).brightness);
    final accent = colorScheme.primary;
    return SizedBox(
      width: 168,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 118,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0.12)],
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.eco_rounded, size: 40, color: accent.withValues(alpha: 0.8)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: freshness, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          '${listing.freshnessScore}%',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.cropType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatGhs(listing.price)} / ${listing.unit}',
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    if (listing.tag != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              listing.tag!,
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.auto_awesome_rounded, size: 10, color: colorScheme.onSurface),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.colorScheme, required this.summary, required this.alertCount});

  final ColorScheme colorScheme;
  final FarmerDashboardSummary summary;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    final warning = AgriStatusColors.warning(Theme.of(context).brightness);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                colorScheme: colorScheme,
                dotColor: colorScheme.primary,
                value: formatGhs(summary.todaysEarnings),
                label: "Today's Earnings",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                colorScheme: colorScheme,
                dotColor: colorScheme.primary,
                value: '${summary.activeOrders}',
                label: 'Active Orders',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                colorScheme: colorScheme,
                dotColor: warning,
                value: '$alertCount',
                label: 'Freshness Alerts',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                colorScheme: colorScheme,
                dotColor: colorScheme.secondary,
                value: '${summary.profileViews}',
                label: 'Profile Views',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.colorScheme,
    required this.dotColor,
    required this.value,
    required this.label,
  });

  final ColorScheme colorScheme;
  final Color dotColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: dotColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
