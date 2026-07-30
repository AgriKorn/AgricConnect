import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/buyer_profile_mock.dart';

String _initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// Overlays the real signed-in user's name/initials/location onto the mock
/// profile so the Marketplace header and Buyer Profile screen (which read
/// from different sources) never disagree on who's logged in.
final buyerProfileProvider = Provider<BuyerProfileDetails>((ref) {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return mockBuyerProfile;
  final region = user.region?.trim();
  return BuyerProfileDetails(
    name: user.name,
    initials: _initialsOf(user.name),
    tier: mockBuyerProfile.tier,
    location: (region != null && region.isNotEmpty) ? region : mockBuyerProfile.location,
  );
});

final deliveryAddressesProvider = Provider<List<DeliveryAddress>>((ref) => mockDeliveryAddresses);

final savedPaymentMethodsProvider = Provider<List<SavedPaymentMethod>>((ref) => mockSavedPaymentMethods);

class BuyerPreferencesController extends Notifier<BuyerPreferences> {
  @override
  BuyerPreferences build() => mockBuyerPreferences;

  void toggleOrderStatusUpdates() => state = state.copyWith(orderStatusUpdates: !state.orderStatusUpdates);
  void togglePriceAlerts() => state = state.copyWith(priceAlerts: !state.priceAlerts);
  void toggleFreshnessNotifications() => state = state.copyWith(freshnessNotifications: !state.freshnessNotifications);
  void toggleMarketingOffers() => state = state.copyWith(marketingOffers: !state.marketingOffers);
}

final buyerPreferencesProvider = NotifierProvider<BuyerPreferencesController, BuyerPreferences>(
  BuyerPreferencesController.new,
);
