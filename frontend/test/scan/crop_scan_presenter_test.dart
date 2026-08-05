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

      expect(record.score, 98); // round(100 * (0.97 + 0.5*0.02))
      expect(record.qualityGrade, 'Grade A');
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
      expect(record.attributes.any((a) => a.label == 'Spoilage Detected'), isTrue);
    });

    test('low freshness confidence is flagged for retake', () {
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
      // Freshness-head confidence only — the crop head is deliberately ignored.
      expect(record.confidence, 0.5);
    });

    test('a confident crop guess does not suppress the retake warning', () {
      // The crop head is very sure (0.99) but the freshness head is not (0.45).
      // The old formula took min(crop, freshness) and this case still warned,
      // but the point here is that the crop head must not influence the record
      // at all — species identification is the farmer's job.
      final record = buildScanRecord(
        _result(
          cropType: 'tomato',
          cropConfidence: 0.99,
          freshnessStage: 'fresh',
          freshnessProbs: [0.3, 0.45, 0.25],
          shelfLifeDays: 4,
        ),
        id: 'scan-4',
        capturedAt: DateTime(2026, 1, 1),
      );

      expect(record.confidence, 0.45);
      expect(
        record.attributes.any((a) => a.label.contains('Low Confidence')),
        isTrue,
      );
    });

    test('the record never carries a crop species, price or shelf life', () {
      // Regression guard for the three things the engine must not decide. All
      // were removed from ScanRecord, so this is enforced by the type system —
      // this test documents the intent and fails if any of them returns.
      final record = buildScanRecord(
        _result(
          cropType: 'cucumber',
          cropConfidence: 0.88,
          freshnessStage: 'fresh',
          freshnessProbs: [0.05, 0.9, 0.05],
          shelfLifeDays: 5,
        ),
        id: 'scan-5',
        capturedAt: DateTime(2026, 1, 1),
      );

      final json = record.toJson();
      expect(json.containsKey('cropType'), isFalse);
      expect(json.containsKey('recommendedPrice'), isFalse);
      expect(json.containsKey('priceUnit'), isFalse);
      // Shelf life came from the model's crop guess, so it is gone too.
      expect(json.containsKey('shelfLifeDays'), isFalse);
      expect(json.containsKey('shelfLifeLabel'), isFalse);
    });

    test('neither the crop label nor the model shelf-life affects the record', () {
      // Both are ignored now, so nine different crops with nine different
      // in-graph shelf-life values must all yield the same freshness output.
      final scores = <int>{};
      for (var i = 0; i < CropScanModel.cropNames.length; i++) {
        final crop = CropScanModel.cropNames[i];
        final record = buildScanRecord(
          _result(
            cropType: crop,
            cropConfidence: 0.9,
            freshnessStage: 'fresh',
            freshnessProbs: [0.05, 0.9, 0.05],
            shelfLifeDays: i.toDouble(), // varies per crop; must be ignored
          ),
          id: 'scan-$crop',
          capturedAt: DateTime(2026, 1, 1),
        );
        scores.add(record.score);
        expect(record.qualityGrade, 'Grade A');
      }
      // Identical freshness input -> identical score for all nine crops.
      expect(scores, hasLength(1));
    });

    test('round-trips through JSON', () {
      final record = buildScanRecord(
        _result(
          cropType: 'okra',
          cropConfidence: 0.8,
          freshnessStage: 'aging',
          freshnessProbs: [0.7, 0.2, 0.1],
          shelfLifeDays: 3,
        ),
        id: 'scan-6',
        capturedAt: DateTime.utc(2026, 1, 1),
        imagePath: '/tmp/photo.jpg',
      );

      final restored = ScanRecord.fromJson(record.toJson());

      expect(restored.id, record.id);
      expect(restored.score, record.score);
      expect(restored.qualityGrade, record.qualityGrade);
      expect(restored.confidence, record.confidence);
      expect(restored.imagePath, '/tmp/photo.jpg');
      expect(restored.attributes.map((a) => a.label), record.attributes.map((a) => a.label));
    });
  });
}
