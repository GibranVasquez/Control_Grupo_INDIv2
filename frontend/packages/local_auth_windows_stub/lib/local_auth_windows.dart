import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

export 'package:local_auth_platform_interface/types/auth_messages.dart';
export 'package:local_auth_platform_interface/types/auth_options.dart';
export 'package:local_auth_platform_interface/types/biometric_type.dart';
export 'types/auth_messages_windows.dart';

/// Reemplazo sin código nativo de la implementación real de `local_auth_windows`.
/// Existe solo para satisfacer la dependencia transitiva de `local_auth` en Windows;
/// `BiometriaService.soportadaEnPlataforma` ya excluye Windows antes de llamar nada de esto,
/// así que estos métodos nunca deberían ejecutarse en la práctica.
class LocalAuthWindows extends LocalAuthPlatform {
  static void registerWith() {
    LocalAuthPlatform.instance = LocalAuthWindows();
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      false;

  @override
  Future<bool> deviceSupportsBiometrics() async => false;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => const [];

  @override
  Future<bool> isDeviceSupported() async => false;

  @override
  Future<bool> stopAuthentication() async => false;
}
