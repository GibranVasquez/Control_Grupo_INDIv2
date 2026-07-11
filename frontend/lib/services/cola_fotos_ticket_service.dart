import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una foto de ticket que no se pudo subir al backend (sin señal, o la carga
/// todavía no terminó de sincronizarse vía PowerSync) y quedó pendiente de
/// reintentar más adelante.
class TicketPendiente {
  const TicketPendiente({
    required this.cargaId,
    required this.rutaLocal,
    required this.encoladoEn,
  });

  final String cargaId;

  /// Ruta persistente (no la ruta temporal original de image_picker, que el
  /// SO puede limpiar): ver [ColaFotosTicketService.agregar].
  final String rutaLocal;
  final DateTime encoladoEn;

  factory TicketPendiente.fromJson(Map<String, dynamic> json) => TicketPendiente(
        cargaId: json['carga_id'] as String,
        rutaLocal: json['ruta_local'] as String,
        encoladoEn: DateTime.parse(json['encolado_en'] as String),
      );

  Map<String, dynamic> toJson() => {
        'carga_id': cargaId,
        'ruta_local': rutaLocal,
        'encolado_en': encoladoEn.toIso8601String(),
      };
}

/// Cola persistente (SharedPreferences + JSON, mismo criterio que
/// CatalogoCacheService: son pocos elementos, no vale la pena Hive/Isar) de
/// fotos de ticket que no se lograron subir al momento de comprobar la carga.
///
/// La ruta original de `image_picker` vive en un directorio temporal que el
/// SO puede limpiar en cualquier momento; por eso [agregar] copia el archivo
/// a un directorio propio de la app (`getApplicationSupportDirectory()`)
/// antes de encolarlo, para que sobreviva un reinicio de la app o del
/// dispositivo mientras sigue sin señal.
class ColaFotosTicketService {
  ColaFotosTicketService(this._prefs);

  final SharedPreferences _prefs;

  static const _clave = 'cola_fotos_ticket_pendientes';

  List<TicketPendiente> listar() {
    final crudo = _prefs.getString(_clave);
    if (crudo == null) return const [];
    final decodificado = jsonDecode(crudo) as List<dynamic>;
    return decodificado
        .cast<Map<String, dynamic>>()
        .map(TicketPendiente.fromJson)
        .toList();
  }

  Future<void> agregar({required String cargaId, required String rutaLocal}) async {
    final directorio = await getApplicationSupportDirectory();
    final carpetaPendientes = Directory(path.join(directorio.path, 'tickets_pendientes'));
    await carpetaPendientes.create(recursive: true);
    final rutaPersistente = path.join(
      carpetaPendientes.path,
      'ticket_$cargaId${path.extension(rutaLocal)}',
    );
    await File(rutaLocal).copy(rutaPersistente);

    final actuales = listar().where((t) => t.cargaId != cargaId).toList();
    await _guardar([
      ...actuales,
      TicketPendiente(cargaId: cargaId, rutaLocal: rutaPersistente, encoladoEn: DateTime.now()),
    ]);
  }

  Future<void> quitar(String cargaId) async {
    final actuales = listar();
    final objetivo = actuales.where((t) => t.cargaId == cargaId).firstOrNull;
    if (objetivo != null) {
      final archivo = File(objetivo.rutaLocal);
      if (await archivo.exists()) await archivo.delete();
    }
    await _guardar(actuales.where((t) => t.cargaId != cargaId).toList());
  }

  Future<void> _guardar(List<TicketPendiente> items) async {
    await _prefs.setString(_clave, jsonEncode(items.map((t) => t.toJson()).toList()));
  }
}
