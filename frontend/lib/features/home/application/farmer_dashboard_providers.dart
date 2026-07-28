import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../marketplace/data/marketplace_repository.dart';
import '../data/farmer_dashboard_mock.dart';

final farmerDashboardSummaryProvider = Provider<FarmerDashboardSummary>((ref) {
  return mockDashboardSummary;
});

final farmerProfileDetailsProvider = Provider<FarmerProfileDetails>((ref) {
  return mockFarmerProfileDetails;
});

/// Backed by GET/POST /listings — a farmer's real, persisted listings.
class FarmerListingsController extends AsyncNotifier<List<FarmerListingSummary>> {
  @override
  Future<List<FarmerListingSummary>> build() {
    return ref.read(marketplaceRepositoryProvider).fetchMyListings();
  }

  Future<void> addListing({
    required String cropType,
    required double quantityKg,
    required int freshnessScore,
    required int shelfLifeDays,
    required double farmerLat,
    required double farmerLong,
    required double pricePerKg,
  }) async {
    await ref.read(marketplaceRepositoryProvider).createListing(
          cropType: cropType,
          quantityKg: quantityKg,
          freshnessScore: freshnessScore,
          shelfLifeDays: shelfLifeDays,
          farmerLat: farmerLat,
          farmerLong: farmerLong,
          pricePerKg: pricePerKg,
        );
    ref.invalidateSelf();
    await future;
  }
}

final farmerListingsProvider = AsyncNotifierProvider<FarmerListingsController, List<FarmerListingSummary>>(
  FarmerListingsController.new,
);

final freshnessAlertsProvider = Provider<List<FreshnessAlertItem>>((ref) {
  return mockFreshnessAlerts;
});
