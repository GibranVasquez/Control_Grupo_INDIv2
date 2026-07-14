import 'package:dio/dio.dart';

/// Traduce un error de red/API a un mensaje corto y en español que un usuario
/// no técnico pueda entender, en vez de mostrarle el `toString()` crudo de un
/// [DioException] (que suele incluir el stack de tipo interno de Dio).
///
/// [accion] describe en minúsculas qué se intentaba hacer (ej. "registrar la
/// carga"), para armar mensajes tipo "No se pudo registrar la carga...".
String mensajeErrorRed(Object error, {required String accion}) {
  if (error is! DioException) {
    return 'No se pudo $accion. Intenta de nuevo.';
  }

  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Sin conexión a internet. Se reintentará cuando vuelva la señal.';
    case DioExceptionType.badResponse:
      final codigo = error.response?.statusCode ?? 0;
      if (codigo >= 500) {
        return 'El servidor tuvo un problema. Intenta de nuevo en unos minutos.';
      }
      final mensajeServidor = _mensajeDelCuerpo(error.response?.data);
      return mensajeServidor ?? 'No se pudo $accion. Intenta de nuevo.';
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
    default:
      return 'No se pudo $accion. Intenta de nuevo.';
  }
}

/// El backend propio devuelve errores como `{"error": "mensaje legible"}`
/// (ver AppError en backend/src). Si el cuerpo trae ese formato, se reutiliza
/// tal cual en vez del mensaje genérico.
String? _mensajeDelCuerpo(dynamic cuerpo) {
  if (cuerpo is Map && cuerpo['error'] is String) {
    return cuerpo['error'] as String;
  }
  return null;
}
