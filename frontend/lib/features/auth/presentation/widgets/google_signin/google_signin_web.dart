import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import '../../../../../core/config/supabase_config.dart';
import '../../../application/auth_controller.dart';
import '../../../data/models/user_role.dart';

/// Google Identity Services (what google_sign_in_web wraps) only allows
/// triggering sign-in through its own rendered button — calling
/// GoogleSignIn.signIn() imperatively from a regular button throws on web.
/// So instead of a press handler, this renders Google's button and listens
/// for the account it produces.
///
/// One shared instance: renderButton() and onCurrentUserChanged both need
/// to talk to the same underlying GIS client, not a fresh one per rebuild.
final GoogleSignIn _webGoogleSignIn = GoogleSignIn(serverClientId: SupabaseConfig.googleWebClientId);

Widget buildGoogleAuthButton({
  required ColorScheme colorScheme,
  required bool loading,
  UserRole? role,
}) {
  return _WebGoogleButton(loading: loading, role: role);
}

class _WebGoogleButton extends ConsumerStatefulWidget {
  const _WebGoogleButton({required this.loading, this.role});

  final bool loading;
  final UserRole? role;

  @override
  ConsumerState<_WebGoogleButton> createState() => _WebGoogleButtonState();
}

class _WebGoogleButtonState extends ConsumerState<_WebGoogleButton> {
  StreamSubscription<GoogleSignInAccount?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _webGoogleSignIn.onCurrentUserChanged.listen((account) {
      if (account != null) {
        unawaited(ref.read(authControllerProvider.notifier).completeGoogleSignIn(account, role: widget.role));
      }
    });
    // Required once before renderButton()'s button is actually interactive
    // (also surfaces a One Tap prompt for a previously-authorized account).
    unawaited(_webGoogleSignIn.signInSilently());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const SizedBox(
        height: 54,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    return SizedBox(height: 54, child: Center(child: web.renderButton()));
  }
}
