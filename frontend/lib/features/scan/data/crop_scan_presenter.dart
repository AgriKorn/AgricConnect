import 'crop_scan_model.dart';
import 'scan_record.dart';

/// Below this crop-classification confidence, the scan is treated as "no
/// recognizable crop" rather than a real result. The model has a fixed
/// 9-crop vocabulary and no "not a crop" class (see ai/README.md) — its
/// softmax always picks *something*, even for a hand, a table, or an empty
/// background, just with a low winning probability. This is the app's own
/// calibration, not a model output.
///
/// IMPORTANT — this is a best-effort catch, not a reliable one: on-device
/// testing against real non-crop photos (a person, a phone, a map, a logo)
/// showed confidences of 42-75% and top-2 margins of 12-64 points, while a
/// real, correctly-identified tomato photo scored only 51.2% with a 14.5pt
/// margin. Those ranges overlap — no confidence or margin cutoff can
/// cleanly separate "real crop, just uncertain" from "confidently wrong
/// guess on a non-crop photo" with this model. A cutoff this low only
/// catches the most extreme non-crop cases; the real safety net is that
/// the identified crop is shown prominently on the result screen (see
/// ScanResultScreen) so the farmer can immediately spot and reject a wrong
/// guess via Retake. Properly fixing this needs the model itself to be
/// retrained with an explicit "not a crop" class — out of scope for this
/// app; see ai/MODEL_REPORT.md for the model's other known limitations.
const noCropConfidenceThreshold = 0.45;

/// Thrown by [ScanController] when [CropScanResult.cropConfidence] is below
/// [noCropConfidenceThreshold] — the capture screen shows this message and
/// stays put instead of navigating to a result screen with a guessed crop.
class NoCropDetectedException implements Exception {
  const NoCropDetectedException();

  @override
  String toString() => 'No crop detected. Point the camera directly at the produce and try again.';
}

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

/// Continuous 0-100 score from the full freshness distribution (not just
/// the argmax stage), so e.g. a narrow fresh/aging call still lands mid-
/// range instead of snapping to 100 or 50. Exposed separately from
/// [buildScanRecord] so callers can compute it before an async pricing
/// lookup (see ScanController._fetchRealPrice) without duplicating the
/// formula.
int computeFreshnessScore(CropScanResult result) {
  final freshProb = result.freshnessProbs[CropScanModel.freshNames.indexOf('fresh')];
  final agingProb = result.freshnessProbs[CropScanModel.freshNames.indexOf('aging')];
  return ((freshProb + 0.5 * agingProb) * 100).round().clamp(0, 100);
}

/// Converts a raw model prediction into the [ScanRecord] shape the scan
/// result / add-listing UI already expects. All presentation choices below
/// (score formula, grade cutoffs, price heuristic) are this app's own
/// calibration — the model itself only outputs crop, freshness stage, and
/// shelf-life days (see ai/README.md).
///
/// [recommendedPrice] should come from the backend's real
/// `/pricing/recommend` (see PricingRepository) whenever that succeeded;
/// the local placeholder table below is only a fallback for when it's
/// unreachable (offline, unconfigured region, no reference price yet).
ScanRecord buildScanRecord(
  CropScanResult result, {
  required String id,
  required DateTime capturedAt,
  String? imagePath,
  double? recommendedPrice,
}) {
  final score = computeFreshnessScore(result);

  final qualityGrade = score >= 80 ? 'Grade A' : (score >= 50 ? 'Grade B' : 'Grade C');

  final basePrice = _basePricePerKg[result.cropType] ?? 5.0;
  final resolvedPrice = recommendedPrice ?? (basePrice * (0.35 + 0.65 * score / 100) * 2).round() / 2; // nearest 0.5

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
    qualityGrade: qualityGrade,
    recommendedPrice: resolvedPrice,
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
