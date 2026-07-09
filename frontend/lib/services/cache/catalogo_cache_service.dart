import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Caché genérica en disco (SharedPreferences + JSON) para catálogos casi-estáticos
/// (obras, ingenieros, tipos de combustible/vehículo): cambian poco, se leen mucho, y no
/// vale la pena pedirlos a Supabase en cada apertura de la app. No es para datos que cambian
/// seguido (solicitudes, cargas) — para eso el patrón correcto es offline-first con sync, no esto.
///
/// Se eligió SharedPreferences sobre Hive/Isar a propósito: son listas pequeñas (decenas de
/// filas, no miles) sin necesidad de queries — Hive/Isar añadirían generación de código y
/// bindings nativos sin beneficio real para este caso de uso.
class CatalogoCacheService {
  const CatalogoCacheService(this._prefs);

  final SharedPreferences _prefs;

  static const _sufijoDatos = '_datos';
  static const _sufijoTimestamp = '_ts';

  /// null si no hay nada en caché o si ya expiró según [vigencia].
  List<Map<String, dynamic>>? leer(
    String clave, {
    Duration vigencia = const Duration(hours: 12),
  }) {
    final crudo = _prefs.getString('$clave$_sufijoDatos');
    final timestampMs = _prefs.getInt('$clave$_sufijoTimestamp');
    if (crudo == null || timestampMs == null) return null;

    final guardadoEn = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    if (DateTime.now().difference(guardadoEn) > vigencia) return null;

    final decodificado = jsonDecode(crudo) as List<dynamic>;
    return decodificado.cast<Map<String, dynamic>>();
  }

  Future<void> guardar(String clave, List<Map<String, dynamic>> datos) async {
    await _prefs.setString('$clave$_sufijoDatos', jsonEncode(datos));
    await _prefs.setInt(
      '$clave$_sufijoTimestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> invalidar(String clave) async {
    await _prefs.remove('$clave$_sufijoDatos');
    await _prefs.remove('$clave$_sufijoTimestamp');
  }
}
