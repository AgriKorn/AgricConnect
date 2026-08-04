import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/marketplace_mock.dart';
import '../data/marketplace_repository.dart';

enum ListingSort { freshnessDesc, priceAsc, priceDesc }

extension ListingSortX on ListingSort {
  String get label => switch (this) {
    ListingSort.freshnessDesc => 'Freshest first',
    ListingSort.priceAsc => 'Price: low to high',
    ListingSort.priceDesc => 'Price: high to low',
  };
}

/// Real active listings from GET /marketplace.
final marketplaceListingsProvider = FutureProvider<List<MarketplaceListing>>((ref) async {
  final repository = ref.watch(marketplaceRepositoryProvider);
  return repository.fetchListings();
});

/// Real single-listing detail from GET /marketplace/:id, for the product
/// detail screen — farmer name/region, quantity, shelf life.
final marketplaceListingDetailProvider =
    FutureProvider.family<MarketplaceListingDetail, String>((ref, id) async {
  final repository = ref.watch(marketplaceRepositoryProvider);
  return repository.fetchListingDetail(id);
});

/// A single farmer's active listings — GET /marketplace?farmerId=..., for
/// their store page. Keyed by farmerId so navigating between two different
/// farmers' stores doesn't show stale data from whichever was viewed first.
final farmerStoreListingsProvider =
    FutureProvider.family<List<MarketplaceListing>, String>((ref, farmerId) async {
  final repository = ref.watch(marketplaceRepositoryProvider);
  return repository.fetchListings(farmerId: farmerId);
});

/// null means "All Crops".
final marketplaceCategoryFilterProvider = StateProvider<ProduceCategory?>((ref) => null);

final marketplaceSearchQueryProvider = StateProvider<String>((ref) => '');

final marketplaceSortProvider = StateProvider<ListingSort>((ref) => ListingSort.freshnessDesc);

/// Listings tapped/selected on the marketplace grid — driving the bottom
/// cart button that takes them all to checkout together.
final selectedMarketplaceListingsProvider = StateProvider<Set<MarketplaceListing>>((ref) => {});

/// Filtered/sorted view over whatever [marketplaceListingsProvider] currently
/// holds. Deliberately doesn't fall back to placeholder data while loading or
/// on error — [marketplace_screen.dart] renders those states itself from
/// [marketplaceListingsProvider] directly, so this only needs to handle the
/// real (possibly stale-while-refetching) list.
final filteredMarketplaceListingsProvider = Provider<List<MarketplaceListing>>((ref) {
  final category = ref.watch(marketplaceCategoryFilterProvider);
  final query = ref.watch(marketplaceSearchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(marketplaceSortProvider);
  final rawList = ref.watch(marketplaceListingsProvider).valueOrNull ?? const <MarketplaceListing>[];

  final result = rawList
      .where((listing) => category == null || listing.category == category)
      .where((listing) => query.isEmpty || listing.name.toLowerCase().contains(query))
      .toList();

  result.sort((a, b) => switch (sort) {
    ListingSort.freshnessDesc => b.freshnessScore.compareTo(a.freshnessScore),
    ListingSort.priceAsc => a.pricePerUnit.compareTo(b.pricePerUnit),
    ListingSort.priceDesc => b.pricePerUnit.compareTo(a.pricePerUnit),
  });

  return result;
});
