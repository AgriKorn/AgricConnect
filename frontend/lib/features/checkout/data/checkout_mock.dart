/// Network preference shown at checkout — cosmetic only. Paystack's own
/// hosted payment page (opened via the real authorizationUrl) is what
/// actually confirms the network and completes the charge.
enum PaymentMethod { mtnMomo, vodafone }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.mtnMomo => 'MTN MoMo',
    PaymentMethod.vodafone => 'Vodafone',
  };
}
