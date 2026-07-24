import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_prefs.dart';

const _onboardingCompleteKey = 'onboarding_complete';

/// Gates the first-launch onboarding carousel (see
/// features/onboarding/presentation/onboarding_screen.dart) from reappearing
/// on later unauthenticated visits — checked in the router redirect guard
/// alongside AuthStatus.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(localPrefsProvider).getString(_onboardingCompleteKey) == 'true';
  }

  Future<void> complete() async {
    state = true;
    await ref.read(localPrefsProvider).setString(_onboardingCompleteKey, 'true');
  }
}

final onboardingControllerProvider = NotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);
