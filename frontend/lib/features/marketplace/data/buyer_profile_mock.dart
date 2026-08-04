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

/// Notification toggle state — persisted via PATCH /users/profile
/// (buyer_profile_providers.dart), not local-only.
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
