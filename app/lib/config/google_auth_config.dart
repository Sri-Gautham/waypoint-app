/// From Google Cloud Console (APIs & Services > Credentials). See the
/// "Web application" OAuth client you create there — its Client ID goes
/// here AND into Supabase's Google provider settings (Authentication >
/// Providers > Google). This is what makes the ID token's audience match
/// what Supabase expects to verify, regardless of which platform
/// (iOS/Android/Web) actually issued it.
///
/// Google Sign-In stays a no-op (silently fails) while this is empty.
class GoogleAuthConfig {
  static const webClientId = '';
}
