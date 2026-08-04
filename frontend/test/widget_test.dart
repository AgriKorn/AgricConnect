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
    expect(find.text('Region'), findsOneWidget);
    expect(find.text('Town / City'), findsOneWidget);
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

  testWidgets('Scan flow reaches the result screen and caches a result', (
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

    await tester.tap(find.text('Start Scanning'));
    await tester.pumpAndSettle();

    expect(find.text('Allow camera access?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('AI Analysis'), findsOneWidget);
    expect(find.text('Create Listing'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
    expect(find.text('Grade A'), findsOneWidget);
  });
}
