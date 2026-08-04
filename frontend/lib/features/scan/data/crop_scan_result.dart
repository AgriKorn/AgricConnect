/// Raw decoded output of one `agriconnect.tflite` inference call (see
/// ai/README.md "Using the model"). No presentation logic lives here —
/// `CropScanModel.predict` only reports what the model actually said.
///
/// Platform-independent on purpose: both the real (native) and web-stub
/// `CropScanModel` implementations produce this same shape.
class CropScanResult {
  const CropScanResult({
    required this.cropType,
    required this.cropConfidence,
    required this.freshnessStage,
    required this.freshnessConfidence,
    required this.freshnessProbs,
    required this.shelfLifeDays,
  });

  /// One of the model's 9 known crop names (carrot, cucumber, mango, okra,
  /// orange, pepper, plantain, potato, tomato).
  final String cropType;
  final double cropConfidence;

  /// One of 'aging', 'fresh', 'spoiled'.
  final String freshnessStage;
  final double freshnessConfidence;

  /// Full softmax over [aging, fresh, spoiled], in that order — lets
  /// callers use the whole distribution (e.g. for a continuous freshness
  /// score) instead of just the winning class.
  final List<double> freshnessProbs;

  /// Estimated days of shelf life remaining, computed in-graph — already
  /// consistent with ai/shelf_life.py, no separate lookup needed.
  final double shelfLifeDays;
}
