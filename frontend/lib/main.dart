import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/storage/local_prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // This app must work on patchy rural networks (PRD 7.1) — the type
  // system itself can't depend on a CDN fetch. Falls back to the platform
  // default font instead of blocking on a network request for Inter.
  GoogleFonts.config.allowRuntimeFetching = true;
  await Hive.initFlutter();
  final localPrefs = await LocalPrefs.open();
  // Only used to broker native Google Sign-In (see core/config/supabase_config.dart)
  // — AgriConnect's own JWTs are still the source of truth for every API call.
  await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);

  runApp(ProviderScope(
    overrides: [localPrefsProvider.overrideWithValue(localPrefs)],
    child: const AgriConnectApp(),
  ));
}

class AgriConnectApp extends ConsumerWidget {
  const AgriConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      title: 'AgriConnect',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
