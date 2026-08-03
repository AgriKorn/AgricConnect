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

class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.cropType,
    required this.score,
    required this.shelfLifeLabel,
    required this.qualityGrade,
    required this.recommendedPrice,
    required this.priceUnit,
    required this.confidence,
    required this.attributes,
    required this.capturedAt,
    this.imagePath,
  });

  final String id;
  final String cropType;
  final int score;
  final String shelfLifeLabel; // short display form, e.g. "12 Days"
  final String qualityGrade; // e.g. "Grade A"
  final double recommendedPrice;
  final String priceUnit; // e.g. "crate"
  final double confidence;
  final List<ScanAttribute> attributes;
  final DateTime capturedAt;

  /// Local file path of the actual photo taken for this scan (null on
  /// platforms/devices with no camera, where capture never produced a file).
  final String? imagePath;

  String get semanticLabel => freshnessStateLabel(score);

  ScanRecord copyWith({String? imagePath}) {
    return ScanRecord(
      id: id,
      cropType: cropType,
      score: score,
      shelfLifeLabel: shelfLifeLabel,
      qualityGrade: qualityGrade,
      recommendedPrice: recommendedPrice,
      priceUnit: priceUnit,
      confidence: confidence,
      attributes: attributes,
      capturedAt: capturedAt,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cropType': cropType,
      'score': score,
      'shelfLifeLabel': shelfLifeLabel,
      'qualityGrade': qualityGrade,
      'recommendedPrice': recommendedPrice,
      'priceUnit': priceUnit,
      'confidence': confidence,
      'attributes': attributes.map((a) => a.toJson()).toList(),
      'capturedAt': capturedAt.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      id: json['id'] as String,
      cropType: json['cropType'] as String,
      score: json['score'] as int,
      shelfLifeLabel: json['shelfLifeLabel'] as String,
      qualityGrade: json['qualityGrade'] as String,
      recommendedPrice: (json['recommendedPrice'] as num).toDouble(),
      priceUnit: json['priceUnit'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      attributes: (json['attributes'] as List<dynamic>)
          .map((a) => ScanAttribute.fromJson(a as Map<String, dynamic>))
          .toList(),
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      imagePath: json['imagePath'] as String?,
    );
  }
}
