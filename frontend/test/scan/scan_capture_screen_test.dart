import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:agriconnect/core/storage/local_prefs.dart';
import 'package:agriconnect/features/scan/presentation/scan_capture_screen.dart';

/// Regression tests for the "the model is hardcoded" report: the scan used to
/// fall back to a canned 94% / 54% / 31% cycle whenever real inference was
/// impossible, so a denied camera permission or a failed capture produced a
/// confident-looking score instead of an error. On a release APK every one of
/// those fallback paths was silent (`kDebugMode` logging only).
///
/// A test host has no camera plugin, so `availableCameras()` fails here exactly
/// as it does on a phone with permission denied — which makes this the natural
/// place to pin the behaviour down.
///
/// Deliberately mounts only [ScanCaptureScreen] rather than the whole app: the
/// authenticated shells hold providers that sit in `AsyncLoading`, whose
/// `CircularProgressIndicator`s never stop animating, so `pumpAndSettle` cannot
/// settle there. Every wait below is a bounded `pump`.
/// Opened once in [setUpAll]. It must NOT be opened inside a `testWidgets`
/// body: `Hive.openBox` performs real file I/O, and awaiting real async inside
/// the widget-test fake-async zone deadlocks unless wrapped in
/// `tester.runAsync`. That is exactly why test/widget_test.dart used to hang.
late Box _box;

Widget _harness() {
  return ProviderScope(
    overrides: [localPrefsProvider.overrideWithValue(LocalPrefs(_box))],
    child: const MaterialApp(home: ScanCaptureScreen()),
  );
}

/// Long enough to cover `_initCamera`'s 4s `availableCameras()` timeout, so the
/// screen has definitively settled into its no-camera state.
Future<void> _settleCamera(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.path);
    _box = await Hive.openBox('scan_capture_test');
  });

  setUp(() async {
    // No cached scan, so the screen starts from a clean state each time.
    await _box.clear();
  });

  testWidgets('renders the capture screen when no camera is available', (tester) async {
    await tester.pumpWidget(_harness());
    await _settleCamera(tester);

    expect(find.text('Hold steady'), findsOneWidget);
    // No score of any kind before a scan has been run.
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('tapping the shutter with no camera reports the failure', (tester) async {
    await tester.pumpWidget(_harness());
    await _settleCamera(tester);

    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Camera not ready'), findsOneWidget);
  });

  testWidgets('never fabricates a freshness score when inference cannot run', (tester) async {
    await tester.pumpWidget(_harness());
    await _settleCamera(tester);

    // Three taps: the deleted fallback cycled 94 -> 54 -> 31 across successive
    // scans, so tapping three times is what surfaced the whole hardcoded set.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pump(const Duration(milliseconds: 500));
    }

    for (final fabricated in ['94%', '54%', '31%']) {
      expect(find.text(fabricated), findsNothing, reason: '$fabricated was a hardcoded sample value');
    }
    // Nor any of the sample crop names the engine used to assert.
    for (final crop in ['Tomatoes', 'Cassava', 'Pepper']) {
      expect(find.text(crop), findsNothing, reason: '$crop was a hardcoded sample crop');
    }
    // And we must not have navigated to a result screen.
    expect(find.text('AI Analysis'), findsNothing);
  });

  testWidgets('shutter stays usable after a failure, not stuck loading', (tester) async {
    await tester.pumpWidget(_harness());
    await _settleCamera(tester);

    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    // The camera icon is replaced by a spinner while a scan is in flight. A
    // refused capture must not leave the button in that state forever.
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
  });
}
