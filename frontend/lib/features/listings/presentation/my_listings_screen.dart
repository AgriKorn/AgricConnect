import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/agri_bottom_sheet.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../home/application/farmer_dashboard_providers.dart';
import '../../home/data/farmer_dashboard_mock.dart';

enum _ListingSort { freshnessDesc, priceAsc, priceDesc }

extension on _ListingSort {
  String get label => switch (this) {
    _ListingSort.freshnessDesc => 'Freshest first',
    _ListingSort.priceAsc => 'Price: low to high',
    _ListingSort.priceDesc => 'Price: high to low',
  };
}

const _tabs = ['Active', 'Pending', 'Sold'];

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  String _selectedTab = 'Active';
  _ListingSort _sort = _ListingSort.freshnessDesc;

  void _showSortSheet(BuildContext context) {
    showAgriBottomSheet(
      context,
      builder: (context) {
        return RadioGroup<_ListingSort>(
          groupValue: _sort,
          onChanged: (value) {
            if (value == null) return;
            setState(() => _sort = value);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sort by', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final sort in _ListingSort.values)
                RadioListTile<_ListingSort>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(sort.label),
                  value: sort,
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final listingsAsync = ref.watch(farmerListingsProvider);
    final listings = (listingsAsync.valueOrNull ?? const [])
        .where((listing) => listing.status == _selectedTab)
        .toList()
      ..sort((a, b) => switch (_sort) {
        _ListingSort.freshnessDesc => b.freshnessScore.compareTo(a.freshnessScore),
        _ListingSort.priceAsc => a.price.compareTo(b.price),
        _ListingSort.priceDesc => b.price.compareTo(a.price),
      });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Listings',
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      _AddButton(colorScheme: colorScheme, onPressed: () => context.push('/farmer/listings/add')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _StatusTabs(
                    colorScheme: colorScheme,
                    selected: _selectedTab,
                    onSelect: (tab) => setState(() => _selectedTab = tab),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${listings.length} ${_selectedTab.toLowerCase()} crop${listings.length == 1 ? '' : 's'}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: () => _showSortSheet(context),
                        child: Icon(Icons.tune_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => ref.refresh(farmerListingsProvider.future),
                    child: listingsAsync.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : listingsAsync.hasError
                        ? EmptyState(
                            icon: Icons.error_outline_rounded,
                            message: 'Could not load your listings. Pull down to retry.',
                          )
                        : listings.isEmpty
                        ? ListView(
                            children: [
                              EmptyState(
                                icon: Icons.grass_outlined,
                                message: 'No ${_selectedTab.toLowerCase()} listings yet.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                            itemCount: listings.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) => _ListingRow(listing: listings[index], colorScheme: colorScheme),
                          ),
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

class _AddButton extends StatelessWidget {
  const _AddButton({required this.colorScheme, required this.onPressed});

  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: 'Add a listing',
        icon: Icon(Icons.add_rounded, color: colorScheme.onPrimary),
        onPressed: onPressed,
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.colorScheme, required this.selected, required this.onSelect});

  final ColorScheme colorScheme;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final tab in _tabs)
            Expanded(
              child: _StatusTab(
                label: tab,
                active: tab == selected,
                colorScheme: colorScheme,
                onTap: () => onSelect(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
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
      child: AnimatedContainer(
        duration: kAgriConnectDuration,
        curve: kAgriConnectCurve,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing, required this.colorScheme});

  final FarmerListingSummary listing;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final freshness = freshnessColorFor(listing.freshnessScore, Theme.of(context).brightness);
    final accent = colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 190,
                    width: 210,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0.12)],
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.eco_rounded, size: 48, color: accent.withValues(alpha: 0.8)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  listing.cropType,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatGhs(listing.price)} / ${listing.unit}',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if (listing.tag != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          listing.tag!,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: freshness, borderRadius: BorderRadius.circular(999)),
              child: Text(
                '${listing.freshnessScore}%',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
