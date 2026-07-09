import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Recuerda las últimas credenciales que iniciaron sesión con éxito, para poder ofrecer
/// "Ingresar con Huella/FaceID" sin pedir usuario/contraseña de nuevo en ese dispositivo.
class CredencialesStorage {
  const CredencialesStorage();

  static const _storage = FlutterSecureStorage();
  static const _claveUsuario = 'ultimo_usuario';
  static const _clavePassword = 'ultimo_password';

  Future<void> guardar({required String usuario, required String password}) async {
    await _storage.write(key: _claveUsuario, value: usuario);
    await _storage.write(key: _clavePassword, value: password);
  }

  Future<({String usuario, String password})?> leer() async {
    final usuario = await _storage.read(key: _claveUsuario);
    final password = await _storage.read(key: _clavePassword);
    if (usuario == null || password == null) return null;
    return (usuario: usuario, password: password);
  }

  Future<void> limpiar() async {
    await _storage.delete(key: _claveUsuario);
    await _storage.delete(key: _clavePassword);
  }
}
