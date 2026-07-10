import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Fuente única del JWT emitido por `POST /auth/login`.
///
/// Tanto [ApiClient] (header `Authorization`) como el conector de PowerSync
/// (`fetchCredentials`) leen el mismo token de aquí: no hay un login aparte
/// para PowerSync, es el mismo JWT que ya emite nuestro backend (ver
/// backend/powersync/POWERSYNC.md, sección 2).
///
/// Se guarda en flutter_secure_storage (Keychain/Keystore), no en
/// SharedPreferences en claro: es un JWT firmado que autoriza tanto a la API
/// REST como a la replicación de PowerSync.
class TokenStorage {
  const TokenStorage();

  static const _storage = FlutterSecureStorage();
  static const _claveToken = 'jwt_token';

  Future<void> guardar(String token) async {
    await _storage.write(key: _claveToken, value: token);
  }

  Future<String?> leer() => _storage.read(key: _claveToken);

  Future<void> limpiar() async {
    await _storage.delete(key: _claveToken);
  }
}
