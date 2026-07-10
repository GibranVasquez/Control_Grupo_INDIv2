import 'package:dio/dio.dart';

import 'token_storage.dart';

/// URL base de la API REST propia (backend/src/), no de PowerSync (ver
/// powersync_client.dart para ese endpoint). Configurable en build/run con
/// `--dart-define=API_URL=https://...`; por defecto apunta al backend local
/// (backend/.env: PORT=4000).
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:4000',
);

/// Se invoca cuando la API responde 401 (token vencido, revocado, o cuenta
/// desactivada): quien construya [ApiClient] decide qué hacer, normalmente
/// limpiar la sesión en memoria (sesionProvider) para que app_router.dart
/// redirija solo a /login (ver providers.dart).
typedef OnUnauthorized = void Function();

/// Cliente HTTP único para toda la API REST propia.
///
/// Agrega automáticamente `Authorization: Bearer <token>` (leyendo el JWT de
/// [TokenStorage], el mismo que usa PowerSync) y, ante un 401, limpia la
/// sesión guardada y notifica a [onUnauthorized] antes de dejar que el error
/// siga propagándose al llamador original.
class ApiClient {
  ApiClient({
    required this.tokenStorage,
    OnUnauthorized? onUnauthorized,
    String? baseUrl,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.leer();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            await tokenStorage.limpiar();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio dio;
  final TokenStorage tokenStorage;
}
