/// Buyer Profile header — derived from the real signed-in user
/// (buyer_profile_providers.dart), not a separate backend entity.
class BuyerProfileDetails {
  const BuyerProfileDetails({
    required this.name,
    required this.initials,
    required this.location,
  });

  final String name;
  final String initials;
  final String location;
}

/// Notification toggles are UI-only preferences — there is no backend
/// endpoint to persist them yet, so they reset on next login. Left as
/// local-only state rather than removed, since flipping a switch and
/// having it silently do nothing is a smaller, more familiar gap than
/// showing invented account data (addresses/payment methods) as if real.
class BuyerPreferences {
  const BuyerPreferences({
    required this.orderStatusUpdates,
    required this.priceAlerts,
    required this.freshnessNotifications,
    required this.marketingOffers,
  });

  final bool orderStatusUpdates;
  final bool priceAlerts;
  final bool freshnessNotifications;
  final bool marketingOffers;

  BuyerPreferences copyWith({
    bool? orderStatusUpdates,
    bool? priceAlerts,
    bool? freshnessNotifications,
    bool? marketingOffers,
  }) {
    return BuyerPreferences(
      orderStatusUpdates: orderStatusUpdates ?? this.orderStatusUpdates,
      priceAlerts: priceAlerts ?? this.priceAlerts,
      freshnessNotifications: freshnessNotifications ?? this.freshnessNotifications,
      marketingOffers: marketingOffers ?? this.marketingOffers,
    );
  }
}

const mockBuyerPreferences = BuyerPreferences(
  orderStatusUpdates: true,
  priceAlerts: true,
  freshnessNotifications: false,
  marketingOffers: false,
);
