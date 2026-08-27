/// From Google Cloud Console (APIs & Services > Credentials). See the
/// "Web application" OAuth client you create there — its Client ID goes
/// here AND into Supabase's Google provider settings (Authentication >
/// Providers > Google). This is what makes the ID token's audience match
/// what Supabase expects to verify, regardless of which platform
/// (iOS/Android/Web) actually issued it.
///
/// Google Sign-In stays a no-op (silently fails) while this is empty.
class GoogleAuthConfig {
  static const webClientId = '439878795614-fj0gd1d8rjer0cfsb5caloo2tb67tvb8.apps.googleusercontent.com';

  /// The iOS OAuth client — passed explicitly to GoogleSignIn() instead of
  /// relying on a GoogleService-Info.plist / Info.plist GIDClientID key
  /// (this app has neither).
  static const iosClientId = '439878795614-7aemcbk0tg0nv0nvkcmqv1qgmsuj0lcs.apps.googleusercontent.com';
}
