import 'package:local_auth_platform_interface/types/auth_messages.dart';

/// Copia mínima del tipo real: `local_auth`'s facade lo instancia directamente
/// (`WindowsAuthMessages()`) sin pasar por `LocalAuthPlatform`, así que el stub también
/// necesita exportarlo aunque nunca se use en la práctica (Windows queda sin biometría).
class WindowsAuthMessages extends AuthMessages {
  const WindowsAuthMessages();

  @override
  Map<String, String> get args => const <String, String>{};
}
