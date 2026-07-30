import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long the logo-only splash screen stays up before the router lets it
/// move on to onboarding/login. Overridden to [Duration.zero] in widget
/// tests so they don't pay a real wall-clock wait.
final splashMinDurationProvider = Provider<Duration>((ref) => const Duration(seconds: 2));

/// True once [splashMinDurationProvider] has elapsed since app start. The
/// router redirect guard (core/router/app_router.dart) holds on /splash
/// until both this and session restoration are done, so the splash is
/// visible for a fixed minimum time regardless of how fast auth resolves.
class SplashTimerController extends Notifier<bool> {
  @override
  bool build() {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    Future.delayed(ref.read(splashMinDurationProvider), () {
      if (!disposed) state = true;
    });
    return false;
  }
}

final splashTimerProvider = NotifierProvider<SplashTimerController, bool>(
  SplashTimerController.new,
);
