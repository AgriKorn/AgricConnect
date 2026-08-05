import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_prefs.dart';
import '../data/crop_scan_model.dart';
import '../data/crop_scan_presenter.dart';
import '../data/scan_record.dart';

const _scanCacheKey = 'latest_scan_record';

/// A scan could not be produced. Carries a farmer-facing [message]; the UI
/// shows it verbatim.
///
/// This type exists because the scan used to *silently* fall back to canned
/// sample results whenever real inference was impossible — no camera, denied
/// permission, a failed capture, or web (where `tflite_flutter` cannot run at
/// all). The screen then presented a hardcoded 94% / 54% / 31% cycle as if it
/// were a measurement, so a broken camera and a genuine reading looked
/// identical. A scan now either reports a real inference or fails visibly.
class ScanUnavailableException implements Exception {
  const ScanUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

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
  Future<CropScanModel>? _modelFuture;

  /// Re-entrancy guard for [captureAndAnalyze], tracked separately from
  /// [ScanState.isScanning] — that flag flips on the instant the shutter is
  /// tapped (see [beginCapture]), before this method runs, so it cannot also
  /// mean "a scan is in flight".
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

  /// Flips [ScanState.isScanning] on immediately, before the camera has even
  /// finished taking the photo — `takePicture()` is a real hardware delay
  /// (autofocus, exposure, JPEG encode) and without this the screen looked
  /// frozen with no acknowledgement the tap registered.
  void beginCapture() {
    state = state.copyWith(isScanning: true, errorMessage: null);
  }

  /// Abandons an in-progress capture, clearing the loading state and recording
  /// [message] for the UI. Used when the failure happens before inference —
  /// e.g. the camera is unavailable or `takePicture()` threw.
  void failCapture(String message) {
    state = state.copyWith(isScanning: false, errorMessage: message);
  }

  /// Runs real on-device inference on [imagePath].
  ///
  /// Throws [ScanUnavailableException] when no real inference is possible on
  /// this platform, and rethrows anything else after recording a message. It
  /// never returns a fabricated result.
  Future<ScanRecord> captureAndAnalyze({required String imagePath}) async {
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
      final model = await _model();
      final bytes = await File(imagePath).readAsBytes();
      final prediction = await model.predict(bytes);
      final result = buildScanRecord(
        prediction,
        id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
        capturedAt: DateTime.now(),
        imagePath: imagePath,
      );

      await ref
          .read(localPrefsProvider)
          .setString(_scanCacheKey, jsonEncode(result.toJson()));

      state = state.copyWith(isScanning: false, lastResult: result);

      if (kDebugMode) {
        debugPrint('Freshness scan finished in ${stopwatch.elapsedMilliseconds} ms');
      }

      return result;
    } on UnsupportedError {
      // `tflite_flutter` is dart:ffi-based and has no web implementation, so
      // CropScanModel.load() throws here on Flutter Web. Previously this was
      // swallowed into the canned sample cycle, which is why the web build
      // appeared to "scan" and always returned 94% first.
      const message =
          'On-device scanning is not available in the web app. '
          'Install the AgriConnect Android app to scan produce.';
      state = state.copyWith(isScanning: false, errorMessage: message);
      throw const ScanUnavailableException(message);
    } catch (error) {
      // Surface something actionable instead of a bare "try again" — a missing
      // model asset, an undecodable photo, and a tensor mismatch are very
      // different problems and used to be indistinguishable.
      final message = 'Scan failed: ${_describe(error)}';
      state = state.copyWith(isScanning: false, errorMessage: message);
      if (kDebugMode) debugPrint('Scan failed: $error');
      rethrow;
    } finally {
      _analyzing = false;
    }
  }

  String _describe(Object error) {
    if (error is FormatException) return 'the photo could not be read. Try again.';
    if (error is FileSystemException) return 'the captured photo could not be opened.';
    return 'unexpected error running the freshness model.';
  }
}

final scanControllerProvider = NotifierProvider<ScanController, ScanState>(
  ScanController.new,
);
