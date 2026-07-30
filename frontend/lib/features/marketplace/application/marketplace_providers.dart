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

/// Fetches produce listings directly from live AWS API / fallback repository
final marketplaceListingsProvider = FutureProvider<List<MarketplaceListing>>((ref) async {
  final repository = ref.watch(marketplaceRepositoryProvider);
  return repository.fetchListings();
});

/// null means "All Crops".
final marketplaceCategoryFilterProvider = StateProvider<ProduceCategory?>((ref) => null);

final marketplaceSearchQueryProvider = StateProvider<String>((ref) => '');

final marketplaceSortProvider = StateProvider<ListingSort>((ref) => ListingSort.freshnessDesc);

/// Listings tapped/selected on the marketplace grid — driving the bottom
/// cart button that takes them all to checkout together.
final selectedMarketplaceListingsProvider = StateProvider<Set<MarketplaceListing>>((ref) => {});

final filteredMarketplaceListingsProvider = Provider<List<MarketplaceListing>>((ref) {
  final category = ref.watch(marketplaceCategoryFilterProvider);
  final query = ref.watch(marketplaceSearchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(marketplaceSortProvider);
  final listingsAsync = ref.watch(marketplaceListingsProvider);

  final rawList = listingsAsync.maybeWhen(
    data: (list) => list,
    orElse: () => mockMarketplaceListings,
  );

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
