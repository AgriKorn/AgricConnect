import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_prefs.dart';
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

  @override
  ScanState build() {
    _restoreCachedResult();
    return ScanState.initial;
  }

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

  Future<ScanRecord> captureAndAnalyze() async {
    if (state.isScanning) {
      final existing = state.lastResult;
      if (existing != null) {
        return existing;
      }
    }

    state = state.copyWith(isScanning: true, errorMessage: null);
    final stopwatch = Stopwatch()..start();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      final result = _sampleResults[_sampleIndex % _sampleResults.length];
      _sampleIndex += 1;

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
    }
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
