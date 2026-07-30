import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency.dart';
import '../../../core/utils/freshness.dart';
import '../../../core/widgets/agri_bottom_sheet.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../checkout/presentation/checkout_screen.dart';
import '../application/marketplace_providers.dart';
import '../data/marketplace_mock.dart';

/// Buyer Marketplace (design system section 7): brand header + avatar ->
/// search + sort -> category chips -> a 2-column grid of listings.
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final listings = ref.watch(filteredMarketplaceListingsProvider);
    final userName = ref.watch(authControllerProvider).user?.name;
    final selected = ref.watch(selectedMarketplaceListingsProvider);

    return Scaffold(
      floatingActionButton: selected.isEmpty
          ? null
          : _CartFab(
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
                  child: _MarketplaceHeader(colorScheme: colorScheme, userName: userName),
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
                  child: listings.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off_rounded,
                          message: 'No produce matches your search.',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.74,
                          ),
                          itemCount: listings.length,
                          itemBuilder: (context, index) =>
                              _ListingTile(listing: listings[index], colorScheme: colorScheme),
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

String _initialsOf(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

class _MarketplaceHeader extends StatelessWidget {
  const _MarketplaceHeader({required this.colorScheme, required this.userName});

  final ColorScheme colorScheme;
  final String? userName;

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
          child: CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primary,
            child: Text(
              _initialsOf(userName),
              style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
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

class _CartFab extends StatelessWidget {
  const _CartFab({required this.colorScheme, required this.count, required this.onPressed});

  final ColorScheme colorScheme;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          onPressed: onPressed,
          child: const Icon(Icons.shopping_cart_rounded),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            constraints: const BoxConstraints(minWidth: 22),
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colorScheme.surface, width: 2),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onError, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListingTile extends ConsumerWidget {
  const _ListingTile({required this.listing, required this.colorScheme});

  final MarketplaceListing listing;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freshness = freshnessColorFor(listing.freshnessScore, Theme.of(context).brightness);
    final accent = colorScheme.primary;
    final selected = ref.watch(selectedMarketplaceListingsProvider).contains(listing);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: selected ? Border.all(color: colorScheme.primary, width: 3) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(selected ? 19 : 22),
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.6),
          child: InkWell(
            onTap: () {
              final notifier = ref.read(selectedMarketplaceListingsProvider.notifier);
              final next = Set<MarketplaceListing>.from(notifier.state);
              if (!next.remove(listing)) next.add(listing);
              notifier.state = next;
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: listing.imageAsset != null
                            ? Image.asset(listing.imageAsset!, fit: BoxFit.cover)
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0.12)],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(listing.category.icon, size: 44, color: accent.withValues(alpha: 0.8)),
                                ),
                              ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: freshness, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.eco_rounded, size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                '${listing.freshnessScore}% Fresh',
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                            child: Icon(Icons.check_rounded, size: 16, color: colorScheme.onPrimary),
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
                        listing.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatGhs(listing.pricePerUnit)} / ${listing.unit}',
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
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
