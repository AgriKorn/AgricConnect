import 'dart:typed_data';

import 'crop_scan_result.dart';

/// Web stub for [CropScanModel] — `tflite_flutter` uses `dart:ffi`, which
/// the web compiler cannot build at all (not "unsupported at runtime", a
/// hard compile error). This file exists purely so the app still compiles
/// for web; see crop_scan_model.dart's conditional export and
/// crop_scan_model_io.dart for the real Android/iOS/desktop implementation.
///
/// [ScanController] catches the [UnsupportedError] from [load] and falls
/// back to the same mock-result cycling used on devices with no camera.
class CropScanModel {
  CropScanModel._();

  static const modelAsset = 'assets/models/agriconnect.tflite';
  static const inputSize = 224;
  static const cropNames = [
    'carrot',
    'cucumber',
    'mango',
    'okra',
    'orange',
    'pepper',
    'plantain',
    'potato',
    'tomato',
  ];
  static const freshNames = ['aging', 'fresh', 'spoiled'];

  static Future<CropScanModel> load() {
    throw UnsupportedError(
      'On-device crop scanning is not available on web (tflite_flutter has '
      'no web support). Use an Android/iOS device or desktop build.',
    );
  }

  void close() {}

  Future<CropScanResult> predict(Uint8List imageBytes) async {
    throw UnsupportedError('On-device crop scanning is not available on web.');
  }
}
