import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_data.dart';

/// The identity fields an OAuth provider hands back on sign-in — only
/// populated the first time a given provider authenticates this account
/// (Apple in particular never repeats the name on later sign-ins).
class AuthResult {
  const AuthResult({required this.isNewUser, this.firstName, this.lastName});

  final bool isNewUser;
  final String? firstName;
  final String? lastName;
}

/// Wraps Supabase Auth's native-token sign-in for Apple and Google, plus
/// the profile row every account gets (see the `profiles` table / the
/// `handle_new_user` trigger that creates it).
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;
  bool get isSignedIn => currentSession != null;

  String _randomNonce([int length = 32]) {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

  Future<AuthResult> signInWithApple() async {
    final rawNonce = _randomNonce();
    final hashedNonce = _sha256(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple sign-in did not return an identity token.');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // Apple only ever includes the name on the FIRST authorization for a
    // given account, so this is the one chance to capture it.
    return AuthResult(
      isNewUser: response.user?.createdAt == response.user?.lastSignInAt,
      firstName: credential.givenName,
      lastName: credential.familyName,
    );
  }

  Future<AuthResult> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in did not return an identity token.');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );

    final nameParts = (googleUser.displayName ?? '').trim().split(' ');
    return AuthResult(
      isNewUser: response.user?.createdAt == response.user?.lastSignInAt,
      firstName: nameParts.isNotEmpty ? nameParts.first : null,
      lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : null,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await GoogleSignIn().signOut().catchError((_) => null);
  }

  /// Loads the signed-in user's `profiles` row into an [OnboardingData]
  /// (kept as the app's in-memory profile model — see profile_tab.dart /
  /// home_tab.dart, which already render from it).
  Future<OnboardingData> loadProfile() async {
    final user = _client.auth.currentUser;
    final data = OnboardingData();
    if (user == null) return data;

    data.email = user.email ?? '';

    final row = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row == null) return data;

    data.firstName = (row['first_name'] as String?) ?? '';
    data.lastName = (row['last_name'] as String?) ?? '';
    data.phone = (row['phone'] as String?) ?? '';
    data.street = (row['home_street'] as String?) ?? '';
    data.apt = (row['home_unit'] as String?) ?? '';
    data.city = (row['home_city'] as String?) ?? '';
    data.state = (row['home_state'] as String?) ?? '';
    data.zip = (row['home_zip'] as String?) ?? '';
    data.faceIdEnabled = (row['face_id_enabled'] as bool?) ?? false;
    return data;
  }

  Future<void> saveProfile(OnboardingData data) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').update({
      'first_name': data.firstName,
      'last_name': data.lastName,
      'phone': data.phone,
      'home_street': data.street,
      'home_unit': data.apt,
      'home_city': data.city,
      'home_state': data.state,
      'home_zip': data.zip,
    }).eq('id', user.id);
  }

  Future<void> setFaceIdEnabled(bool enabled) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').update({'face_id_enabled': enabled}).eq('id', user.id);
  }
}
