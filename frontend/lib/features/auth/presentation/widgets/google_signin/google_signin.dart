// Conditional export so the web-only implementation (which imports
// package:google_sign_in_web/web_only.dart, unavailable outside a web
// compile) never gets pulled into the Android/iOS build. Mirrors the
// pattern from the official google_sign_in example app
// (packages/google_sign_in/google_sign_in/example/lib/src/sign_in_button.dart).
export 'google_signin_stub.dart'
    if (dart.library.js_util) 'google_signin_web.dart'
    if (dart.library.io) 'google_signin_mobile.dart';
