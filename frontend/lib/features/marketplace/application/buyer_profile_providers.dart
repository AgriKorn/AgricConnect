import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/buyer_profile_mock.dart';

final buyerProfileProvider = Provider<BuyerProfileDetails>((ref) => mockBuyerProfile);

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
