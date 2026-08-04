import 'crop_scan_model.dart';
import 'scan_record.dart';

/// Crops the dataset only has 'fresh'/'spoiled' folders for (no 'aging'
/// examples were collected) — mirrors TWO_STAGE_CROPS in ai/shelf_life.py.
/// An "aging" prediction for these is extrapolated, not photo-calibrated.
const _twoStageCrops = {'cucumber', 'okra', 'orange'};

/// Placeholder GH₵/kg reference prices, pending a real pricing feed (the
/// backend's `mofa_price_references` table isn't exposed to the app yet —
/// see backend/prisma/schema.prisma). Scaled by freshness below so the
/// recommendation still reacts to scan quality instead of being a flat rate.
const _basePricePerKg = {
  'carrot': 7.0,
  'cucumber': 5.0,
  'mango': 5.0,
  'okra': 10.0,
  'orange': 4.0,
  'pepper': 15.0,
  'plantain': 6.0,
  'potato': 6.0,
  'tomato': 8.0,
};

/// Converts a raw model prediction into the [ScanRecord] shape the scan
/// result / add-listing UI already expects. All presentation choices below
/// (score formula, grade cutoffs, price heuristic) are this app's own
/// calibration — the model itself only outputs crop, freshness stage, and
/// shelf-life days (see ai/README.md).
ScanRecord buildScanRecord(
  CropScanResult result, {
  required String id,
  required DateTime capturedAt,
  String? imagePath,
}) {
  final freshProb = result.freshnessProbs[CropScanModel.freshNames.indexOf('fresh')];
  final agingProb = result.freshnessProbs[CropScanModel.freshNames.indexOf('aging')];

  // Continuous 0-100 score from the full freshness distribution (not just
  // the argmax stage), so e.g. a narrow fresh/aging call still lands mid-
  // range instead of snapping to 100 or 50.
  final score = ((freshProb + 0.5 * agingProb) * 100).round().clamp(0, 100);

  final qualityGrade = score >= 80 ? 'Grade A' : (score >= 50 ? 'Grade B' : 'Grade C');

  final basePrice = _basePricePerKg[result.cropType] ?? 5.0;
  final recommendedPrice = (basePrice * (0.35 + 0.65 * score / 100) * 2).round() / 2; // nearest 0.5

  final attributes = <ScanAttribute>[
    switch (result.freshnessStage) {
      'fresh' => const ScanAttribute(label: 'Good Condition', kind: ScanAttributeKind.positive),
      'aging' => const ScanAttribute(label: 'Softening / Aging', kind: ScanAttributeKind.caution),
      _ => const ScanAttribute(label: 'Spoilage Detected', kind: ScanAttributeKind.caution),
    },
    if (result.cropConfidence < 0.6 || result.freshnessConfidence < 0.6)
      const ScanAttribute(label: 'Low Confidence — Retake in Better Light', kind: ScanAttributeKind.caution),
    if (_twoStageCrops.contains(result.cropType) && result.freshnessStage == 'aging')
      const ScanAttribute(label: 'Aging Estimate Extrapolated', kind: ScanAttributeKind.caution),
  ];

  return ScanRecord(
    id: id,
    cropType: _capitalize(result.cropType),
    score: score,
    shelfLifeLabel: _shelfLifeLabel(result.shelfLifeDays),
    shelfLifeDays: result.shelfLifeDays,
    qualityGrade: qualityGrade,
    recommendedPrice: recommendedPrice,
    priceUnit: 'kg',
    confidence: result.cropConfidence < result.freshnessConfidence ? result.cropConfidence : result.freshnessConfidence,
    attributes: attributes,
    capturedAt: capturedAt,
    imagePath: imagePath,
  );
}

String _shelfLifeLabel(double days) {
  if (days < 1) {
    final hours = (days * 24).round().clamp(1, 23);
    return '$hours Hours';
  }
  return '${days.round()} Days';
}

String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
