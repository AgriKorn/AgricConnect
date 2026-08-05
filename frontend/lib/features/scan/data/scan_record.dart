import 'package:flutter/material.dart';

import '../../../core/utils/freshness.dart';

/// What kind of signal a [ScanAttribute] represents, driving both its icon
/// and chip styling on the result screen.
enum ScanAttributeKind { positive, pest, caution, certification }

extension ScanAttributeKindX on ScanAttributeKind {
  /// Null means "no icon" — a plain certification-style tag (e.g. Organic).
  IconData? get icon => switch (this) {
    ScanAttributeKind.positive => Icons.check_rounded,
    ScanAttributeKind.pest => Icons.pest_control_rounded,
    ScanAttributeKind.caution => Icons.priority_high_rounded,
    ScanAttributeKind.certification => null,
  };
}

class ScanAttribute {
  const ScanAttribute({required this.label, required this.kind});

  final String label;
  final ScanAttributeKind kind;

  Map<String, dynamic> toJson() => {'label': label, 'kind': kind.name};

  factory ScanAttribute.fromJson(Map<String, dynamic> json) {
    return ScanAttribute(
      label: json['label'] as String,
      kind: ScanAttributeKind.values.byName(json['kind'] as String),
    );
  }
}

/// The outcome of one real on-device scan: a freshness reading, nothing else.
///
/// Deliberately carries **no crop species, no price and no shelf life**:
///
/// * Species — the model has a fixed 9-crop vocabulary and no "not a crop"
///   class, so it always emits some crop with some confidence, including for
///   photos that contain no produce at all. Naming the produce is the farmer's
///   job, done by typing it on the listing form. Nothing in this record, and
///   nothing in [buildScanRecord], may read the model's crop head.
/// * Price — the previous recommendation was derived from that same untrusted
///   species guess (a wrong guess silently moved the farmer's suggested
///   price), so it has been removed rather than shown as an "AI price tip".
/// * Shelf life — `agriconnect.tflite` computes `shelf_life_days` *in-graph*
///   from its own crop guess (ArgMax over the crop head, then Gather against a
///   baked-in table — see ai/README.md), so it inherited the same
///   unreliability. Removed for that reason; the farmer states shelf life on
///   the listing form.
///
/// What remains — the freshness score and the grade derived from it — depends
/// only on the freshness head, which is species-independent.
///
/// There is no "sample"/mock variant of this class any more: if a real
/// inference cannot be run, the scan fails loudly instead of inventing a
/// score. See [ScanController].
class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.score,
    required this.qualityGrade,
    required this.confidence,
    required this.attributes,
    required this.capturedAt,
    this.imagePath,
  });

  final String id;

  /// 0-100, from the model's freshness head only.
  final int score;
  final String qualityGrade; // e.g. "Grade A"

  /// The freshness head's confidence — deliberately *not* combined with the
  /// crop head's, so a confidently-wrong species cannot mask an uncertain
  /// freshness reading. Drives the low-confidence retake caveat in
  /// [ScanAttribute] form; never displayed as a raw number.
  final double confidence;
  final List<ScanAttribute> attributes;
  final DateTime capturedAt;

  /// Local file path of the photo this scan ran on. Always non-null in
  /// practice now — a scan cannot happen without a real image.
  final String? imagePath;

  String get semanticLabel => freshnessStateLabel(score);

  ScanRecord copyWith({String? imagePath}) {
    return ScanRecord(
      id: id,
      score: score,
      qualityGrade: qualityGrade,
      confidence: confidence,
      attributes: attributes,
      capturedAt: capturedAt,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'score': score,
      'qualityGrade': qualityGrade,
      'confidence': confidence,
      'attributes': attributes.map((a) => a.toJson()).toList(),
      'capturedAt': capturedAt.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      id: json['id'] as String,
      score: json['score'] as int,
      qualityGrade: json['qualityGrade'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      attributes: (json['attributes'] as List<dynamic>)
          .map((a) => ScanAttribute.fromJson(a as Map<String, dynamic>))
          .toList(),
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      imagePath: json['imagePath'] as String?,
    );
  }
}
