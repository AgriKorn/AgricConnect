import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/address_repository.dart';
import '../data/buyer_profile_mock.dart';

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
