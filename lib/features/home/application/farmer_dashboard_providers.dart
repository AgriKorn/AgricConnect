import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/farmer_dashboard_mock.dart';

final farmerDashboardSummaryProvider = Provider<FarmerDashboardSummary>((ref) {
  return mockDashboardSummary;
});

final farmerProfileDetailsProvider = Provider<FarmerProfileDetails>((ref) {
  return mockFarmerProfileDetails;
});

/// Mutable so [AddListingScreen] (scan-assisted or manual entry) can append
/// a real listing that then shows up in My Listings — not just a static mock.
class FarmerListingsController extends Notifier<List<FarmerListingSummary>> {
  @override
  List<FarmerListingSummary> build() => List.of(mockFarmerListings);

  void addListing(FarmerListingSummary listing) {
    state = [listing, ...state];
  }
}

final farmerListingsProvider = NotifierProvider<FarmerListingsController, List<FarmerListingSummary>>(
  FarmerListingsController.new,
);

final freshnessAlertsProvider = Provider<List<FreshnessAlertItem>>((ref) {
  return mockFreshnessAlerts;
});
