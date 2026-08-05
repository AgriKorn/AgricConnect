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

Future<Widget> _pumpableApp({
  TokenStorage? tokenStorage,
  Map<String, dynamic>? sessionSnapshot,
  bool onboardingComplete = true,
}) async {
  final box = await Hive.openBox(
    'test_prefs_${DateTime.now().microsecondsSinceEpoch}',
  );
  if (sessionSnapshot != null) {
    await box.put('auth_session_snapshot', jsonEncode(sessionSnapshot));
  }
  if (onboardingComplete) {
    await box.put('onboarding_complete', 'true');
  }
  return ProviderScope(
    overrides: [
      localPrefsProvider.overrideWithValue(LocalPrefs(box)),
      secureStorageProvider.overrideWithValue(
        tokenStorage ?? _FakeTokenStorage(),
      ),
      splashMinDurationProvider.overrideWithValue(Duration.zero),
    ],
    child: const AgriConnectApp(),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Hive.init(Directory.systemTemp.path);
  });

  testWidgets('Unauthenticated user lands on the login screen', (tester) async {
    await tester.pumpWidget(await _pumpableApp());
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('First launch shows onboarding before login', (tester) async {
    await tester.pumpWidget(await _pumpableApp(onboardingComplete: false));
    await tester.pumpAndSettle();

    expect(find.text('Precision Harvesting'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsWidgets);
  });

  testWidgets('Sign up link opens role selection with all three roles', (
    tester,
  ) async {
    await tester.pumpWidget(await _pumpableApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text("I'm a Farmer"), findsOneWidget);
    expect(find.text("I'm a Buyer"), findsOneWidget);
    expect(find.text("I'm a Driver"), findsOneWidget);
  });

  testWidgets('Picking a role opens its registration form', (tester) async {
    await tester.pumpWidget(await _pumpableApp());
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

  testWidgets('Scanning with no camera reports a failure and never invents a score', (
    tester,
  ) async {
    // Regression guard. This test previously asserted `find.text('94%')` —
    // which only ever passed because the scan silently fell back to a
    // hardcoded 94% / 54% / 31% sample cycle whenever real inference was
    // impossible. A test environment has no camera, so that fallback made a
    // broken camera indistinguishable from a genuine reading, on device too.
    // The fallback is gone: no camera must mean a visible failure and no score.
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
        tokenStorage: _FakeTokenStorage(
          accessToken: 'access',
          refreshToken: 'refresh',
        ),
        sessionSnapshot: {'user': sessionSnapshot},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Scanning'));
    // Deliberately not pumpAndSettle: with no camera the capture screen shows
    // an indefinite CircularProgressIndicator, so settling never completes.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Hold steady'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Camera not ready'), findsOneWidget);
    // The whole point: no fabricated freshness score anywhere.
    expect(find.text('94%'), findsNothing);
    expect(find.text('54%'), findsNothing);
    expect(find.text('31%'), findsNothing);
    // And we must still be on the capture screen, not a result screen.
    expect(find.text('AI Analysis'), findsNothing);
  });
}
