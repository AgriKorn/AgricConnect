import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/agri_bottom_sheet.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../checkout/presentation/checkout_screen.dart';
import '../application/marketplace_providers.dart';
import '../data/marketplace_mock.dart';
import 'widgets/listing_grid_tile.dart';

/// Buyer Marketplace (design system section 7): brand header + avatar ->
/// search + sort -> category chips -> a responsive grid of listings.
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final listingsAsync = ref.watch(marketplaceListingsProvider);
    final listings = ref.watch(filteredMarketplaceListingsProvider);
    final selected = ref.watch(selectedMarketplaceListingsProvider);

    return Scaffold(
      floatingActionButton: selected.isEmpty
          ? null
          : MarketplaceCartFab(
              colorScheme: colorScheme,
              count: selected.length,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => CheckoutScreen(listings: selected.toList())),
              ),
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackground(colorScheme: colorScheme),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _MarketplaceHeader(colorScheme: colorScheme),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _SearchRow(colorScheme: colorScheme),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _CategoryChips(colorScheme: colorScheme),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => ref.refresh(marketplaceListingsProvider.future),
                    child: listingsAsync.when(
                      loading: () => ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: CircularProgressIndicator()),
                        ],
                      ),
                      error: (error, _) => ListView(
                        children: [
                          const SizedBox(height: 60),
                          EmptyState(
                            icon: Icons.wifi_off_rounded,
                            message: 'Could not load the marketplace. Pull down to retry.',
                          ),
                        ],
                      ),
                      data: (_) => listings.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 60),
                                EmptyState(
                                  icon: Icons.search_off_rounded,
                                  message: 'No produce matches your search.',
                                ),
                              ],
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) => GridView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCountForWidth(constraints.maxWidth),
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.74,
                                ),
                                itemCount: listings.length,
                                itemBuilder: (context, index) =>
                                    ListingGridTile(listing: listings[index], colorScheme: colorScheme),
                              ),
                            ),
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

class _MarketplaceHeader extends StatelessWidget {
  const _MarketplaceHeader({required this.colorScheme});

  final ColorScheme colorScheme;

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
                'Marketplace',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.go('/buyer/profile'),
          child: const SizedBox(width: 44, height: 44, child: UserAvatar(size: 44)),
        ),
      ],
    );
  }
}

class _SearchRow extends ConsumerWidget {
  const _SearchRow({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            style: TextStyle(color: colorScheme.onSurface),
            onChanged: (value) => ref.read(marketplaceSearchQueryProvider.notifier).state = value,
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              hintText: 'Search fresh produce...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
              prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant, size: 22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _SortButton(colorScheme: colorScheme),
      ],
    );
  }
}

class _SortButton extends ConsumerWidget {
  const _SortButton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: colorScheme.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showSortSheet(context, ref),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.tune_rounded, color: colorScheme.onPrimary, size: 22),
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context, WidgetRef ref) {
    showAgriBottomSheet(
      context,
      builder: (context) {
        final current = ref.watch(marketplaceSortProvider);
        return RadioGroup<ListingSort>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) ref.read(marketplaceSortProvider.notifier).state = value;
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sort by', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final sort in ListingSort.values)
                RadioListTile<ListingSort>(
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
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(marketplaceCategoryFilterProvider);
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _CategoryChip(
            label: 'All Crops',
            active: selected == null,
            colorScheme: colorScheme,
            onTap: () => ref.read(marketplaceCategoryFilterProvider.notifier).state = null,
          ),
          for (final category in ProduceCategory.values) ...[
            const SizedBox(width: 8),
            _CategoryChip(
              label: category.label,
              active: selected == category,
              colorScheme: colorScheme,
              onTap: () => ref.read(marketplaceCategoryFilterProvider.notifier).state = category,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colorScheme.onSurface : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              Icon(Icons.check_rounded, size: 15, color: colorScheme.surface),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? colorScheme.surface : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

