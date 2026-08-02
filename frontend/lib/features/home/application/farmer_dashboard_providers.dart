import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../marketplace/data/marketplace_repository.dart';
import '../data/farmer_dashboard_mock.dart';
import '../data/farmer_dashboard_repository.dart';
import '../data/weather_repository.dart';

/// Real dashboard/profile numbers (earnings, active orders, sales, primary
/// crops, market trend) — GET /dashboard/farmer-summary.
final farmerDashboardSummaryProvider = FutureProvider<FarmerDashboardSummary>((ref) {
  return ref.read(farmerDashboardRepositoryProvider).fetchSummary();
});

/// Real current weather for the farmer's own region (Open-Meteo, no API
/// key). Best-effort — a weather outage shouldn't break the dashboard, so
/// this resolves to null rather than throwing.
final farmerWeatherProvider = FutureProvider<WeatherSnapshot?>((ref) async {
  final summary = await ref.watch(farmerDashboardSummaryProvider.future);
  final (lat, long) = coordinatesForRegion(summary.location);
  try {
    return await ref.read(weatherRepositoryProvider).fetchCurrent(lat: lat, long: long);
  } catch (_) {
    return null;
  }
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
    String? imageUrl,
  }) async {
    await ref.read(marketplaceRepositoryProvider).createListing(
          cropType: cropType,
          quantityKg: quantityKg,
          freshnessScore: freshnessScore,
          shelfLifeDays: shelfLifeDays,
          farmerLat: farmerLat,
          farmerLong: farmerLong,
          pricePerKg: pricePerKg,
          imageUrl: imageUrl,
        );
    ref.invalidateSelf();
    await future;
  }
}

final farmerListingsProvider = AsyncNotifierProvider<FarmerListingsController, List<FarmerListingSummary>>(
  FarmerListingsController.new,
);

/// Real low-freshness listings pulled straight from the farmer's own active
/// listings — replaces the old fixed 2-item mock that never matched what
/// was actually listed.
final freshnessAlertsProvider = Provider<List<FarmerListingSummary>>((ref) {
  final listings = ref.watch(farmerListingsProvider).valueOrNull ?? const [];
  return listings.where((l) => l.status == 'Active' && l.freshnessScore < 60).toList()
    ..sort((a, b) => a.freshnessScore.compareTo(b.freshnessScore));
});
