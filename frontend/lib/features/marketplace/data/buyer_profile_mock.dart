import 'package:flutter/material.dart';

/// Mock data standing in for the real Buyer Profile endpoint until its
/// backend contract is confirmed — same "build against a mock first"
/// pattern used throughout the checklist (see features/home/data).
class BuyerProfileDetails {
  const BuyerProfileDetails({
    required this.name,
    required this.initials,
    required this.tier,
    required this.location,
    required this.walletBalance,
  });

  final String name;
  final String initials;
  final String tier;
  final String location;
  final double walletBalance;
}

const mockBuyerProfile = BuyerProfileDetails(
  name: 'Kwame Asante',
  initials: 'KA',
  tier: 'Premium Buyer',
  location: 'Accra, Ghana',
  walletBalance: 1450.25,
);

enum DeliveryAddressType { home, office }

extension DeliveryAddressTypeX on DeliveryAddressType {
  IconData get icon => switch (this) {
    DeliveryAddressType.home => Icons.home_rounded,
    DeliveryAddressType.office => Icons.apartment_rounded,
  };
}

class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.type,
    required this.label,
    required this.detail,
  });

  final String id;
  final DeliveryAddressType type;
  final String label;
  final String detail;
}

const mockDeliveryAddresses = [
  DeliveryAddress(
    id: 'addr1',
    type: DeliveryAddressType.home,
    label: 'Home',
    detail: 'House No. 24, Spintex Road, Accra',
  ),
  DeliveryAddress(
    id: 'addr2',
    type: DeliveryAddressType.office,
    label: 'Office',
    detail: 'Heritage Tower, 6th Floor, Ridge',
  ),
];

enum SavedPaymentType { mtnMobileMoney, visaCard }

class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    required this.maskedNumber,
    this.isDefault = false,
  });

  final String id;
  final SavedPaymentType type;
  final String label;
  final String maskedNumber;
  final bool isDefault;
}

const mockSavedPaymentMethods = [
  SavedPaymentMethod(
    id: 'pm1',
    type: SavedPaymentType.mtnMobileMoney,
    label: 'MTN Mobile Money',
    maskedNumber: '024 •••• 8821',
    isDefault: true,
  ),
  SavedPaymentMethod(
    id: 'pm2',
    type: SavedPaymentType.visaCard,
    label: 'Visa Card',
    maskedNumber: '•••• 4429',
  ),
];

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
