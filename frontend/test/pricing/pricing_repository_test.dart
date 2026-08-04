import 'package:flutter_test/flutter_test.dart';

import 'package:agriconnect/features/pricing/data/pricing_repository.dart';

void main() {
  group('PriceRecommendation.fromJson', () {
    test('parses the backend pricing.service.ts response shape', () {
      final recommendation = PriceRecommendation.fromJson({
        'crop': 'tomato',
        'region': 'Ashanti',
        'freshness': 92,
        'mofaPrice': 15.5,
        'ceiling': 14.26,
        'softFloor': 9.3,
      });

      expect(recommendation.mofaPrice, 15.5);
      expect(recommendation.ceiling, 14.26);
      expect(recommendation.softFloor, 9.3);
    });

    test('coerces integer JSON numbers to double', () {
      final recommendation = PriceRecommendation.fromJson({
        'mofaPrice': 15,
        'ceiling': 14,
        'softFloor': 9,
      });

      expect(recommendation.mofaPrice, 15.0);
      expect(recommendation.ceiling, 14.0);
      expect(recommendation.softFloor, 9.0);
    });
  });
}
