import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:agriconnect/features/scan/data/crop_scan_model.dart';

/// Runs the REAL agriconnect.tflite model on a device/emulator (not
/// flutter_test's flutter_tester host, which has no native TFLite library —
/// see test/scan/crop_scan_model_test.dart). Proves inference is actually
/// running against the photo content, not returning a fixed/mocked result.
Future<Uint8List> _asset(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List();
}

void _printPrediction(String path, dynamic result, {String? expected}) {
  final sorted = List<double>.from(result.cropProbs as List<double>)..sort();
  final top1 = sorted.last;
  final top2 = sorted[sorted.length - 2];
  // ignore: avoid_print
  print(
    '$path -> crop=${result.cropType} (${(result.cropConfidence * 100).toStringAsFixed(1)}%)'
    '${expected != null ? ' expected=$expected' : ''} '
    'margin=${((top1 - top2) * 100).toStringAsFixed(1)}pts '
    'freshness=${result.freshnessStage} (${(result.freshnessConfidence * 100).toStringAsFixed(1)}%)',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late CropScanModel model;

  setUpAll(() async {
    model = await CropScanModel.load();
  });

  tearDownAll(() => model.close());

  testWidgets('classifies real produce photos as different, varying crops', (tester) async {
    final cases = {
      'assets/images/roma tomatoes.png': 'tomato',
      'assets/images/belll pepper.png': 'pepper',
      'assets/images/haden mangoes.png': 'mango',
      'assets/images/carrots.jpg': 'carrot',
    };

    final seenCrops = <String>{};
    for (final entry in cases.entries) {
      final bytes = await _asset(entry.key);
      final result = model.predict(bytes);
      seenCrops.add(result.cropType);
      _printPrediction(entry.key, result, expected: entry.value);
    }

    // If this were hardcoded/mocked, every call would return the exact same
    // fixed result regardless of input — real inference must vary with what
    // is actually in the photo.
    expect(
      seenCrops.length,
      greaterThan(1),
      reason: 'Different produce photos all produced the same crop — looks hardcoded, not real inference.',
    );
  });

  testWidgets('reports raw confidence + margin on clearly non-crop photos (diagnostic)', (tester) async {
    final nonCropAssets = [
      'assets/images/farmer_hero.jpeg',
      'assets/images/phone_holding.png',
      'assets/images/market.png',
      'assets/images/navigation.jpg',
      'assets/images/agri_logo.png',
    ];

    for (final path in nonCropAssets) {
      final bytes = await _asset(path);
      final result = model.predict(bytes);
      _printPrediction(path, result);
    }
  });
}
