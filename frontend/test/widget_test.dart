import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import 'package:agriconnect/core/router/splash_timer_controller.dart';
import 'package:agriconnect/core/storage/local_prefs.dart';
import 'package:agriconnect/core/storage/secure_storage.dart';
import 'package:agriconnect/main.dart';
import 'package:agriconnect/features/auth/data/models/account_status.dart';
import 'package:agriconnect/features/auth/data/models/user_model.dart';
import 'package:agriconnect/features/auth/data/models/user_role.dart';

class _FakeTokenStorage implements TokenStorage {
  _FakeTokenStorage({this._accessToken, this._refreshToken});

  String? _accessToken;
  String? _refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}

/// Opened once in [setUpAll] — see the note there. Reused by every test, with
/// its contents reset per test inside `tester.runAsync`.
late Box _prefsBox;

/// Builds the app under test.
///
/// [tester] is required because seeding the preferences box is real file I/O:
/// `Hive.put` must run inside `tester.runAsync`, or the await never completes
/// and the test hangs until its timeout. This helper previously did
/// `await Hive.openBox(...)` directly in the widget-test zone, which is why
/// this whole file used to stall.
Future<Widget> _pumpableApp(
  WidgetTester tester, {
  TokenStorage? tokenStorage,
  Map<String, dynamic>? sessionSnapshot,
  bool onboardingComplete = true,
}) async {
  await tester.runAsync(() async {
    await _prefsBox.clear();
    if (sessionSnapshot != null) {
      await _prefsBox.put('auth_session_snapshot', jsonEncode(sessionSnapshot));
    }
    if (onboardingComplete) {
      await _prefsBox.put('onboarding_complete', 'true');
    }
  });
  return ProviderScope(
    overrides: [
      localPrefsProvider.overrideWithValue(LocalPrefs(_prefsBox)),
      secureStorageProvider.overrideWithValue(
        tokenStorage ?? _FakeTokenStorage(),
      ),
      splashMinDurationProvider.overrideWithValue(Duration.zero),
    ],
    child: const AgriConnectApp(),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    Hive.init(Directory.systemTemp.path);
    // Opened here, not inside a testWidgets body: real file I/O awaited inside
    // the widget-test fake-async zone deadlocks (see _pumpableApp).
    _prefsBox = await Hive.openBox('test_prefs');
  });

  testWidgets('Unauthenticated user lands on the login screen', (tester) async {
    await tester.pumpWidget(await _pumpableApp(tester));
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('First launch shows onboarding before login', (tester) async {
    await tester.pumpWidget(await _pumpableApp(tester, onboardingComplete: false));
    await tester.pumpAndSettle();

    expect(find.text('Precision Harvesting'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsWidgets);
  });

  testWidgets('Sign up link opens role selection with all three roles', (
    tester,
  ) async {
    await tester.pumpWidget(await _pumpableApp(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text("I'm a Farmer"), findsOneWidget);
    expect(find.text("I'm a Buyer"), findsOneWidget);
    expect(find.text("I'm a Driver"), findsOneWidget);
  });

  testWidgets('Picking a role opens its registration form', (tester) async {
    await tester.pumpWidget(await _pumpableApp(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm a Farmer"));
    await tester.pumpAndSettle();

    expect(find.text('Sign up as Farmer'), findsOneWidget);
    expect(find.text('Region / District'), findsOneWidget);
  });

  testWidgets('Persisted session restores the farmer home shell', (
    tester,
  ) async {
    final sessionSnapshot = UserModel(
      id: 'mock-1',
      role: UserRole.farmer,
      name: 'Ama',
      email: 'ama@example.com',
      phone: '0240000000',
      status: AccountStatus.verified,
      region: 'Ashanti',
    ).toJson();

    await tester.pumpWidget(
      await _pumpableApp(
        tester,
        tokenStorage: _FakeTokenStorage(
          accessToken: 'access',
          refreshToken: 'refresh',
        ),
        sessionSnapshot: {'user': sessionSnapshot},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan Your Harvest'), findsOneWidget);
    expect(find.text('Start Scanning'), findsOneWidget);
  });

  // The scan flow is covered by test/scan/scan_capture_screen_test.dart rather
  // than from here. The previous test in this slot asserted
  // `find.text('94%')` — a value that only ever appeared because the scan
  // silently fell back to a hardcoded 94% / 54% / 31% sample cycle when real
  // inference was impossible, which is the bug that fallback caused. It also
  // tapped an "Allow camera access?" gate that a later commit had already
  // deleted, so it had been failing for some time; nothing in CI runs
  // `flutter test`, so nobody saw it. Driving the capture screen directly
  // avoids this file's `pumpAndSettle` calls, which cannot settle once an
  // authenticated shell is showing a loading spinner.
}
