import 'package:local_auth/local_auth.dart';

/// Thin wrapper around `local_auth` for the Face ID / Touch ID gate shown
/// on relaunch when a user has opted in (see profiles.face_id_enabled).
class BiometricService {
  BiometricService._();
  static final instance = BiometricService._();

  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
  }

  Future<bool> authenticate({String reason = 'Sign in to Waypoint'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } on Exception {
      return false;
    }
  }
}
