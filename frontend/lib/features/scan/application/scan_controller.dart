import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_prefs.dart';
import '../data/crop_scan_model.dart';
import '../data/crop_scan_presenter.dart';
import '../data/scan_record.dart';

const _scanCacheKey = 'latest_scan_record';

class ScanState {
  const ScanState({
    required this.isFlashOn,
    required this.isScanning,
    this.lastResult,
    this.errorMessage,
  });

  final bool isFlashOn;
  final bool isScanning;
  final ScanRecord? lastResult;
  final String? errorMessage;

  ScanState copyWith({
    bool? isFlashOn,
    bool? isScanning,
    ScanRecord? lastResult,
    String? errorMessage,
  }) {
    return ScanState(
      isFlashOn: isFlashOn ?? this.isFlashOn,
      isScanning: isScanning ?? this.isScanning,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: errorMessage,
    );
  }

  static const initial = ScanState(isFlashOn: false, isScanning: false);
}

class ScanController extends Notifier<ScanState> {
  int _sampleIndex = 0;
  Future<CropScanModel>? _modelFuture;

  /// Re-entrancy guard for [captureAndAnalyze], tracked separately from
  /// [ScanState.isScanning] — that flag now flips on the instant the
  /// shutter is tapped (see [beginCapture]), before this method even runs,
  /// so it can no longer double as "a scan is currently in flight" without
  /// every call seeing it already true and short-circuiting to whatever
  /// stale result happens to be cached.
  bool _analyzing = false;

  @override
  ScanState build() {
    _restoreCachedResult();
    ref.onDispose(() {
      // Fire-and-forget: closing the interpreter is best-effort cleanup,
      // not something anything downstream waits on.
      _modelFuture?.then((model) => model.close());
    });
    return ScanState.initial;
  }

  Future<CropScanModel> _model() => _modelFuture ??= CropScanModel.load();

  void _restoreCachedResult() {
    final cachedJson = ref.read(localPrefsProvider).getString(_scanCacheKey);
    if (cachedJson == null) {
      return;
    }

    try {
      final record = ScanRecord.fromJson(
        jsonDecode(cachedJson) as Map<String, dynamic>,
      );
      state = state.copyWith(lastResult: record);
    } catch (_) {
      // Ignore corrupt cache and keep the app usable.
    }
  }

  void toggleFlash() {
    state = state.copyWith(isFlashOn: !state.isFlashOn);
  }

  /// The crop type the upcoming mock-fallback [captureAndAnalyze] call will
  /// resolve to when no real photo is available (no camera on this
  /// device/platform) — lets the capture screen's "detected" label match
  /// the result it's about to navigate to. Meaningless once a real photo is
  /// captured, since real detection isn't known until inference finishes.
  String get previewCropType =>
      _sampleResults[_sampleIndex % _sampleResults.length].cropType;

  /// Flips [ScanState.isScanning] on immediately, before the camera has even
  /// finished taking the photo. [captureAndAnalyze] does this too, but only
  /// once `takePicture()` (a real, noticeable camera-hardware delay) has
  /// already resolved — leaving a dead gap between tapping the shutter and
  /// any visible feedback that the tap was registered at all. The capture
  /// screen calls this the instant the button is pressed instead.
  void beginCapture() {
    state = state.copyWith(isScanning: true, errorMessage: null);
  }

  Future<ScanRecord> captureAndAnalyze({String? imagePath}) async {
    if (_analyzing) {
      final existing = state.lastResult;
      if (existing != null) {
        return existing;
      }
    }
    _analyzing = true;

    state = state.copyWith(isScanning: true, errorMessage: null);
    final stopwatch = Stopwatch()..start();

    try {
      final result = imagePath != null
          ? await _analyzeImage(imagePath)
          : await _analyzeMock();

      await ref
          .read(localPrefsProvider)
          .setString(_scanCacheKey, jsonEncode(result.toJson()));

      state = state.copyWith(isScanning: false, lastResult: result);

      if (kDebugMode) {
        debugPrint(
          'Freshness scan finished in ${stopwatch.elapsedMilliseconds} ms',
        );
      }

      return result;
    } catch (_) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: 'Scan failed. Please try again.',
      );
      rethrow;
    } finally {
      _analyzing = false;
    }
  }

  /// Real on-device inference against `ai/model/agriconnect.tflite`. Falls
  /// back to the mock cycle on web specifically — `tflite_flutter` has no
  /// web support (see crop_scan_model_web.dart), even though the `camera`
  /// plugin can still hand us a real [imagePath] there.
  Future<ScanRecord> _analyzeImage(String imagePath) async {
    try {
      final model = await _model();
      final bytes = await File(imagePath).readAsBytes();
      final prediction = await model.predict(bytes);
      return buildScanRecord(
        prediction,
        id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
        capturedAt: DateTime.now(),
        imagePath: imagePath,
      );
    } on UnsupportedError {
      return _analyzeMock(imagePath: imagePath);
    }
  }

  /// Platforms with no real inference path available — no camera (desktop,
  /// simulators), or web (no `tflite_flutter` support) — cycle through
  /// fixed sample results instead, same as pre-integration behavior.
  Future<ScanRecord> _analyzeMock({String? imagePath}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    final result = _sampleResults[_sampleIndex % _sampleResults.length].copyWith(imagePath: imagePath);
    _sampleIndex += 1;
    return result;
  }
}

final scanControllerProvider = NotifierProvider<ScanController, ScanState>(
  ScanController.new,
);

final _sampleResults = [
  ScanRecord(
    id: 'scan-1',
    cropType: 'Tomatoes',
    score: 94,
    shelfLifeLabel: '12 Days',
    shelfLifeDays: 12,
    qualityGrade: 'Grade A',
    recommendedPrice: 45,
    priceUnit: 'crate',
    confidence: 0.96,
    attributes: const [
      ScanAttribute(label: 'Uniform Color', kind: ScanAttributeKind.positive),
      ScanAttribute(label: 'Firm Texture', kind: ScanAttributeKind.positive),
      ScanAttribute(label: 'No Pests', kind: ScanAttributeKind.pest),
      ScanAttribute(label: 'Organic', kind: ScanAttributeKind.certification),
    ],
    capturedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000, isUtc: true),
  ),
  ScanRecord(
    id: 'scan-2',
    cropType: 'Cassava',
    score: 54,
    shelfLifeLabel: '2 Days',
    shelfLifeDays: 2,
    qualityGrade: 'Grade B',
    recommendedPrice: 28,
    priceUnit: 'bag',
    confidence: 0.91,
    attributes: const [
      ScanAttribute(label: 'Moisture Loss', kind: ScanAttributeKind.caution),
      ScanAttribute(label: 'Surface Intact', kind: ScanAttributeKind.positive),
      ScanAttribute(label: 'Sell Soon', kind: ScanAttributeKind.caution),
    ],
    capturedAt: DateTime.fromMillisecondsSinceEpoch(1710003600000, isUtc: true),
  ),
  ScanRecord(
    id: 'scan-3',
    cropType: 'Pepper',
    score: 31,
    shelfLifeLabel: '8 Hours',
    shelfLifeDays: 8 / 24, // kept consistent with the "8 Hours" label above
    qualityGrade: 'Grade C',
    recommendedPrice: 12,
    priceUnit: 'basket',
    confidence: 0.84,
    attributes: const [
      ScanAttribute(label: 'Softening Visible', kind: ScanAttributeKind.caution),
      ScanAttribute(label: 'Patchy Color', kind: ScanAttributeKind.caution),
      ScanAttribute(label: 'Use Urgently', kind: ScanAttributeKind.caution),
    ],
    capturedAt: DateTime.fromMillisecondsSinceEpoch(1710007200000, isUtc: true),
  ),
];
