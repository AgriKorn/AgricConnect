/// Supabase project config used purely to broker native Google Sign-In:
/// the app exchanges a Google ID token for a Supabase session via
/// [Supabase.instance.client.auth.signInWithIdToken], then hands that
/// session's access token to our own backend (POST /auth/google), which
/// verifies it and issues AgriConnect's own JWT pair. Supabase is not used
/// for anything else client-side — no data access, no other auth methods.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://elqvrqydxpykxurmziky.supabase.co';

  // The anon/public key is safe to ship in a mobile app (it's the client
  // key, gated by RLS) — but a real one hasn't been wired into this project
  // anywhere yet. Replace with the value from Supabase Dashboard > Project
  // Settings > API > "anon public".
  static const String anonKey = 'REPLACE_WITH_SUPABASE_ANON_KEY';

  // Google Cloud OAuth "Web application" client ID — passed as
  // GoogleSignIn(serverClientId:) so the native flow returns an ID token
  // Supabase's Google provider can verify. Not secret (only the paired
  // Client Secret, which lives in Supabase's dashboard, is).
  static const String googleWebClientId =
      '822615047827-6dmoupdn2euffg911g58d8kjdeop0oq1.apps.googleusercontent.com';
}
