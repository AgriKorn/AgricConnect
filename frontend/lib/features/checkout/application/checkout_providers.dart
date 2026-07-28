import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/checkout_mock.dart';

final selectedPaymentMethodProvider = StateProvider<PaymentMethod>((ref) => PaymentMethod.mtnMomo);
