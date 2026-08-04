import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../data/address_repository.dart';
import '../data/buyer_profile_mock.dart';

const _defaultPreferences = BuyerPreferences(
  orderStatusUpdates: true,
  priceAlerts: true,
  freshnessNotifications: false,
  marketingOffers: false,
);

String _initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// Derives the Buyer Profile header directly from the signed-in user — no
/// invented "tier"/membership status, since the backend has no such concept.
final buyerProfileProvider = Provider<BuyerProfileDetails>((ref) {
  final user = ref.watch(authControllerProvider).user;
  final region = user?.region?.trim();
  return BuyerProfileDetails(
    name: user?.name ?? 'Buyer',
    initials: _initialsOf(user?.name ?? ''),
    location: (region != null && region.isNotEmpty) ? region : 'Ghana',
  );
});

/// Real delivery addresses, backed by GET/POST/PATCH/DELETE
/// /api/users/addresses — replaces the previous hardcoded mock list.
class DeliveryAddressesController extends AsyncNotifier<List<DeliveryAddress>> {
  @override
  Future<List<DeliveryAddress>> build() {
    return ref.read(addressRepositoryProvider).fetchAddresses();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(addressRepositoryProvider).fetchAddresses());
  }

  Future<void> add({required String label, required String addressLine, String? region, bool isDefault = false}) async {
    await ref.read(addressRepositoryProvider).createAddress(
          label: label,
          addressLine: addressLine,
          region: region,
          isDefault: isDefault,
        );
    await refresh();
  }

  Future<void> edit(String id, {String? label, String? addressLine, String? region, bool? isDefault}) async {
    await ref.read(addressRepositoryProvider).updateAddress(
          id,
          label: label,
          addressLine: addressLine,
          region: region,
          isDefault: isDefault,
        );
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(addressRepositoryProvider).deleteAddress(id);
    await refresh();
  }
}

final deliveryAddressesProvider = AsyncNotifierProvider<DeliveryAddressesController, List<DeliveryAddress>>(
  DeliveryAddressesController.new,
);

/// Real, persisted via PATCH /users/profile { notificationPreferences }.
/// Each toggle sends the full 4-flag object (not a partial patch) and
/// optimistically updates local state first, reverting only if the save
/// fails — a flipped switch that silently doesn't stick was the original bug.
class BuyerPreferencesController extends AsyncNotifier<BuyerPreferences> {
  @override
  Future<BuyerPreferences> build() async {
    final profile = await ref.read(authRepositoryProvider).fetchProfile();
    return BuyerPreferences(
      orderStatusUpdates: profile.orderStatusUpdates ?? _defaultPreferences.orderStatusUpdates,
      priceAlerts: profile.priceAlerts ?? _defaultPreferences.priceAlerts,
      freshnessNotifications: profile.freshnessNotifications ?? _defaultPreferences.freshnessNotifications,
      marketingOffers: profile.marketingOffers ?? _defaultPreferences.marketingOffers,
    );
  }

  Future<void> _apply(BuyerPreferences Function(BuyerPreferences current) update) async {
    final current = state.valueOrNull ?? _defaultPreferences;
    final next = update(current);
    state = AsyncData(next);
    try {
      await ref.read(authRepositoryProvider).updateProfile({
        'notificationPreferences': {
          'orderStatusUpdates': next.orderStatusUpdates,
          'priceAlerts': next.priceAlerts,
          'freshnessNotifications': next.freshnessNotifications,
          'marketingOffers': next.marketingOffers,
        },
      });
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> toggleOrderStatusUpdates() => _apply((c) => c.copyWith(orderStatusUpdates: !c.orderStatusUpdates));
  Future<void> togglePriceAlerts() => _apply((c) => c.copyWith(priceAlerts: !c.priceAlerts));
  Future<void> toggleFreshnessNotifications() =>
      _apply((c) => c.copyWith(freshnessNotifications: !c.freshnessNotifications));
  Future<void> toggleMarketingOffers() => _apply((c) => c.copyWith(marketingOffers: !c.marketingOffers));
}

final buyerPreferencesProvider = AsyncNotifierProvider<BuyerPreferencesController, BuyerPreferences>(
  BuyerPreferencesController.new,
);
