/// Mock data standing in for the real Checkout/Escrow endpoint until its
/// backend contract is confirmed — same "build against a mock first"
/// pattern used throughout the checklist (see features/home/data).
enum PaymentMethod { mtnMomo, vodafone }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.mtnMomo => 'MTN MoMo',
    PaymentMethod.vodafone => 'Vodafone',
  };
}

/// Flat mock fees (checkout is not yet tied to a real cart/pricing engine).
const mockDeliveryFee = 35.0;
const mockEscrowServiceFee = 5.0;
