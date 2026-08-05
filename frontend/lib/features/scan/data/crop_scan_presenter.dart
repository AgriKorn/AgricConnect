import 'crop_scan_model.dart';
import 'scan_record.dart';

/// Converts a raw model prediction into the [ScanRecord] the scan result /
/// add-listing UI expects.
///
/// **This function must never read [CropScanResult.cropType].** The model has a
/// fixed 9-crop vocabulary and no "not a crop" class, so its crop head always
/// names *something* — a hand, a face, or an empty table all come back as one
/// of the nine crops, sometimes with high confidence. Identifying the produce
/// is the farmer's job (they type it on the listing form); the scan's job is
/// freshness only.
///
/// That invariant is why there is no price here either: the old recommendation
/// multiplied a per-crop base price by the freshness score, so a misidentified
/// crop silently changed the farmer's suggested price. Pricing was removed
/// rather than left resting on an untrusted guess.
///
/// The score / grade cutoffs below are this app's own calibration; the model
/// itself only outputs the freshness distribution and a shelf-life estimate
/// (see ai/README.md).
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

  final attributes = <ScanAttribute>[
    switch (result.freshnessStage) {
      'fresh' => const ScanAttribute(label: 'Good Condition', kind: ScanAttributeKind.positive),
      'aging' => const ScanAttribute(label: 'Softening / Aging', kind: ScanAttributeKind.caution),
      _ => const ScanAttribute(label: 'Spoilage Detected', kind: ScanAttributeKind.caution),
    },
    // Uses only the freshness head's confidence. The crop head's confidence is
    // deliberately ignored — see the note above; a confident wrong species is
    // exactly the failure mode we stopped surfacing.
    if (result.freshnessConfidence < 0.6)
      const ScanAttribute(label: 'Low Confidence — Retake in Better Light', kind: ScanAttributeKind.caution),
  ];

  return ScanRecord(
    id: id,
    score: score,
    shelfLifeLabel: _shelfLifeLabel(result.shelfLifeDays),
    shelfLifeDays: result.shelfLifeDays,
    qualityGrade: qualityGrade,
    confidence: result.freshnessConfidence,
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
