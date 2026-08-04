import 'package:flutter_test/flutter_test.dart';

import 'package:agriconnect/features/scan/data/crop_scan_model.dart';
import 'package:agriconnect/features/scan/data/crop_scan_presenter.dart';
import 'package:agriconnect/features/scan/data/scan_record.dart';

CropScanResult _result({
  required String cropType,
  required double cropConfidence,
  required String freshnessStage,
  required List<double> freshnessProbs,
  required double shelfLifeDays,
}) {
  final freshIdx = CropScanModel.freshNames.indexOf(freshnessStage);
  return CropScanResult(
    cropType: cropType,
    cropConfidence: cropConfidence,
    freshnessStage: freshnessStage,
    freshnessConfidence: freshnessProbs[freshIdx],
    freshnessProbs: freshnessProbs,
    shelfLifeDays: shelfLifeDays,
  );
}

void main() {
  group('buildScanRecord', () {
    test('confidently fresh produce scores high and grades A', () {
      final record = buildScanRecord(
        _result(
          cropType: 'tomato',
          cropConfidence: 0.97,
          freshnessStage: 'fresh',
          freshnessProbs: [0.02, 0.97, 0.01], // [aging, fresh, spoiled]
          shelfLifeDays: 7,
        ),
        id: 'scan-1',
        capturedAt: DateTime(2026, 1, 1),
      );

      expect(record.cropType, 'Tomato');
      expect(record.score, 98); // round(100 * (0.97 + 0.5*0.02))
      expect(record.qualityGrade, 'Grade A');
      expect(record.shelfLifeLabel, '7 Days');
      expect(record.priceUnit, 'kg');
      expect(record.attributes.first.label, 'Good Condition');
      expect(record.attributes.first.kind, ScanAttributeKind.positive);
    });

    test('confidently spoiled produce scores low and grades C', () {
      final record = buildScanRecord(
        _result(
          cropType: 'pepper',
          cropConfidence: 0.9,
          freshnessStage: 'spoiled',
          freshnessProbs: [0.03, 0.02, 0.95],
          shelfLifeDays: 0,
        ),
        id: 'scan-2',
        capturedAt: DateTime(2026, 1, 1),
      );

      expect(record.score, lessThan(10));
      expect(record.qualityGrade, 'Grade C');
      expect(record.shelfLifeLabel, endsWith('Hours'));
      expect(record.attributes.any((a) => a.label == 'Spoilage Detected'), isTrue);
    });

    test('low-confidence prediction is flagged for retake', () {
      final record = buildScanRecord(
        _result(
          cropType: 'mango',
          cropConfidence: 0.42,
          freshnessStage: 'aging',
          freshnessProbs: [0.5, 0.3, 0.2],
          shelfLifeDays: 2,
        ),
        id: 'scan-3',
        capturedAt: DateTime(2026, 1, 1),
      );

      expect(
        record.attributes.any((a) => a.label.contains('Low Confidence')),
        isTrue,
      );
      expect(record.confidence, 0.42); // min(crop, freshness) confidence
    });

    test('aging call on a two-stage crop is flagged as extrapolated', () {
      final record = buildScanRecord(
        _result(
          cropType: 'cucumber',
          cropConfidence: 0.88,
          freshnessStage: 'aging',
          freshnessProbs: [0.7, 0.2, 0.1],
          shelfLifeDays: 3,
        ),
        id: 'scan-4',
        capturedAt: DateTime(2026, 1, 1),
      );

      expect(
        record.attributes.any((a) => a.label == 'Aging Estimate Extrapolated'),
        isTrue,
      );
    });

    test('every known crop resolves to a priced record', () {
      for (final crop in CropScanModel.cropNames) {
        final record = buildScanRecord(
          _result(
            cropType: crop,
            cropConfidence: 0.9,
            freshnessStage: 'fresh',
            freshnessProbs: [0.05, 0.9, 0.05],
            shelfLifeDays: 5,
          ),
          id: 'scan-$crop',
          capturedAt: DateTime(2026, 1, 1),
        );
        expect(record.recommendedPrice, greaterThan(0));
      }
    });
  });
}
