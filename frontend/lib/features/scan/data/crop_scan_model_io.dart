import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'crop_scan_result.dart';

/// Loads and runs `assets/models/agriconnect.tflite` — the on-device crop
/// freshness model described in ai/README.md and ai/MODEL_REPORT.md.
///
/// Label order and preprocessing here mirror `load_and_preprocess()` in
/// ai/pipeline/*.py exactly: resize-with-pad (not stretched) to 224x224,
/// raw 0-255 float32 RGB with no separate normalization — the model graph
/// itself contains the needed rescaling layer.
///
/// Native (Android/iOS/desktop) implementation only — `tflite_flutter` uses
/// `dart:ffi`, which the web compiler can't build at all. See
/// crop_scan_model.dart for the conditional export that picks this file vs.
/// crop_scan_model_web.dart, and crop_scan_model_web.dart for why web needs
/// a separate stub rather than just failing to compile.
class CropScanModel {
  CropScanModel._(this._interpreter);

  static const modelAsset = 'assets/models/agriconnect.tflite';
  static const inputSize = 224;

  // Must exactly match agriconnect.tflite's output label ordering
  // (ai/pipeline/02_functional_eval.py CROP_NAMES / FRESH_NAMES).
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

  final Interpreter _interpreter;

  static Future<CropScanModel> load() async {
    final interpreter = await Interpreter.fromAsset(modelAsset);
    return CropScanModel._(interpreter);
  }

  void close() => _interpreter.close();

  /// Decodes [imageBytes] (whatever format the camera/gallery produced),
  /// preprocesses it to match training, and runs one inference pass.
  CropScanResult predict(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Could not decode captured image for scanning.');
    }

    final input = [_resizeWithPadToInputTensor(decoded)];

    // Output shapes/order per ai/README.md: crop_output [1,9],
    // fresh_output [1,3], shelf_life_days [1] (batch-only, no class dim).
    final cropOutput = [List<double>.filled(cropNames.length, 0)];
    final freshOutput = [List<double>.filled(freshNames.length, 0)];
    final shelfLifeOutput = List<double>.filled(1, 0);

    _interpreter.runForMultipleInputs(input, {
      0: cropOutput,
      1: freshOutput,
      2: shelfLifeOutput,
    });

    final cropProbs = cropOutput[0];
    final freshProbs = freshOutput[0];
    final cropIdx = _argmax(cropProbs);
    final freshIdx = _argmax(freshProbs);

    return CropScanResult(
      cropType: cropNames[cropIdx],
      cropConfidence: cropProbs[cropIdx],
      freshnessStage: freshNames[freshIdx],
      freshnessConfidence: freshProbs[freshIdx],
      freshnessProbs: freshProbs,
      shelfLifeDays: shelfLifeOutput[0],
    );
  }

  int _argmax(List<double> values) {
    var bestIdx = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[bestIdx]) bestIdx = i;
    }
    return bestIdx;
  }

  /// Equivalent of `tf.image.resize_with_pad`: scales [src] to fit inside
  /// [inputSize]x[inputSize] preserving aspect ratio, then centers it on a
  /// black canvas — never stretches the crop's proportions.
  List<List<List<double>>> _resizeWithPadToInputTensor(img.Image src) {
    final scale = inputSize / src.width < inputSize / src.height
        ? inputSize / src.width
        : inputSize / src.height;
    final resizedW = (src.width * scale).round().clamp(1, inputSize);
    final resizedH = (src.height * scale).round().clamp(1, inputSize);
    final resized = img.copyResize(
      src,
      width: resizedW,
      height: resizedH,
      interpolation: img.Interpolation.linear,
    );

    final canvas = img.Image(width: inputSize, height: inputSize, numChannels: 3);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
    final dx = (inputSize - resizedW) ~/ 2;
    final dy = (inputSize - resizedH) ~/ 2;
    img.compositeImage(canvas, resized, dstX: dx, dstY: dy);

    return List.generate(
      inputSize,
      (y) => List.generate(inputSize, (x) {
        final pixel = canvas.getPixel(x, y);
        return [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
      }),
    );
  }
}
