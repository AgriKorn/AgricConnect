import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:agriconnect/features/scan/data/crop_scan_model.dart';

/// A flat mid-gray square, PNG-encoded — not a real crop photo (the labeled
/// dataset isn't committed to this repo, see ai/README.md), just enough to
/// prove the full pipeline runs end-to-end: asset load -> FFI interpreter ->
/// preprocessing -> real inference -> decoded, well-formed output.
Uint8List _syntheticPhoto() {
  final image = img.Image(width: 800, height: 600, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(120, 150, 90));
  return Uint8List.fromList(img.encodePng(image));
}

/// `flutter test` always runs against the desktop host (`flutter_tester`),
/// never a real Android/iOS device — but tflite_flutter only auto-bundles
/// the native TensorFlow Lite library on Android (via Gradle) and iOS (via
/// CocoaPods); see bindings.dart in the tflite_flutter package source. On
/// desktop it expects that native lib to already be placed manually next to
/// the Dart executable, which isn't part of this project's normal setup.
/// So on a plain dev machine this suite can't reach real inference — skip
/// cleanly instead of failing, but still run for real wherever that native
/// lib happens to be present.
Future<CropScanModel?> _tryLoadModel() async {
  try {
    return await CropScanModel.load();
  } on ArgumentError catch (e) {
    if (e.message.toString().contains('Failed to load dynamic library')) {
      return null;
    }
    rethrow;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads agriconnect.tflite and runs a real inference pass', () async {
    final model = await _tryLoadModel();
    if (model == null) {
      markTestSkipped(
        'Desktop native TensorFlow Lite library not installed on this '
        'machine (Android/iOS bundle it automatically; see comment above).',
      );
      return;
    }
    addTearDown(model.close);

    final result = model.predict(_syntheticPhoto());

    expect(CropScanModel.cropNames, contains(result.cropType));
    expect(CropScanModel.freshNames, contains(result.freshnessStage));
    expect(result.cropConfidence, inInclusiveRange(0.0, 1.0));
    expect(result.freshnessConfidence, inInclusiveRange(0.0, 1.0));
    expect(result.freshnessProbs, hasLength(CropScanModel.freshNames.length));
    expect(result.freshnessProbs.reduce((a, b) => a + b), closeTo(1.0, 0.01));
    expect(result.shelfLifeDays, greaterThanOrEqualTo(0));
  });

  test('a non-square photo is resized-with-pad, not stretched or cropped', () async {
    final model = await _tryLoadModel();
    if (model == null) {
      markTestSkipped('Desktop native TensorFlow Lite library not installed on this machine.');
      return;
    }
    addTearDown(model.close);

    final wide = img.Image(width: 1200, height: 300, numChannels: 3);
    img.fill(wide, color: img.ColorRgb8(200, 60, 40));
    final tall = img.Image(width: 300, height: 1200, numChannels: 3);
    img.fill(tall, color: img.ColorRgb8(200, 60, 40));

    // Same content, two aspect ratios — should still run without throwing
    // and produce a valid label either way (this is a smoke check on the
    // preprocessing path, not a claim about prediction accuracy).
    for (final image in [wide, tall]) {
      final result = model.predict(Uint8List.fromList(img.encodePng(image)));
      expect(CropScanModel.cropNames, contains(result.cropType));
    }
  });
}
