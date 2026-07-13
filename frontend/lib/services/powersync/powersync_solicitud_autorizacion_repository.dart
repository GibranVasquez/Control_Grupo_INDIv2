import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../solicitud_autorizacion_repository.dart';

/// Decisión de transporte: 100% PowerSync local (lectura y escritura).
///
/// Es la entidad offline-first por excelencia, junto con `cargas`: el chofer
/// arma la solicitud sin señal, se inserta de inmediato en SQLite local con
/// `creado_offline = 1`, y PowerSync la sube sola apenas hay red (ver
/// powersync_client.dart, que traduce el insert local a
/// `POST /solicitudes-autorizacion`). [resolver] (autorización/rechazo del
/// administrativo) también es local-first por el mismo motivo: en campo la
/// señal puede ser tan intermitente para el administrativo como para el
/// chofer.
///
/// [crear] siempre genera su propio id (uuid v4) al insertar, ignorando
/// cualquier valor que traiga `solicitud.id` (el objeto de entrada describe
/// los datos a crear, no una fila ya existente — mismo criterio que
/// `SolicitudAutorizacionRepositoryFake` original). Ese mismo id se manda tal
/// cual al backend al subir el cambio (ver powersync_client.dart), que lo
/// valida y lo usa como id real (backend/src/services/solicitudAutorizacion.service.ts) —
/// la fila local y la fila del servidor son siempre el mismo registro, sin
/// duplicados ni ventana en la que desaparezca de la UI.
class PowerSyncSolicitudAutorizacionRepository
    implements SolicitudAutorizacionRepository {
  PowerSyncSolicitudAutorizacionRepository({required this.database});

  final PowerSyncDatabase database;

  static const _uuid = Uuid();

  @override
  Future<void> crear(SolicitudAutorizacion solicitud) async {
    await database.execute(
      '''
      INSERT INTO solicitudes_autorizacion
        (id, chofer_id, vehiculo_id, obra_id, litros_solicitados, comentario,
         estado, creado_en, creado_offline, actividad, responsable)
      VALUES (?, ?, ?, ?, ?, ?, 'pendiente', ?, ?, ?, ?)
      ''',
      [
        _uuid.v4(),
        solicitud.choferId,
        solicitud.vehiculoId,
        solicitud.obraId,
        solicitud.litrosSolicitados,
        solicitud.comentario,
        DateTime.now().toIso8601String(),
        solicitud.creadoOffline ? 1 : 0,
        solicitud.actividad,
        solicitud.responsable,
      ],
    );
  }

  @override
  Future<List<SolicitudAutorizacion>> listarPorChofer(String choferId) async {
    final filas = await database.getAll(
      'SELECT * FROM solicitudes_autorizacion WHERE chofer_id = ? ORDER BY creado_en DESC',
      [choferId],
    );
    return filas
        .map((fila) => SolicitudAutorizacion.fromJson(_filaAJson(fila)))
        .toList();
  }

  @override
  Future<List<SolicitudAutorizacion>> listarPendientesPorObra(
    String obraId,
  ) async {
    final filas = await database.getAll(
      '''
      SELECT * FROM solicitudes_autorizacion
      WHERE obra_id = ? AND estado = 'pendiente'
      ORDER BY creado_en ASC
      ''',
      [obraId],
    );
    return filas
        .map((fila) => SolicitudAutorizacion.fromJson(_filaAJson(fila)))
        .toList();
  }

  @override
  Stream<List<SolicitudAutorizacion>> watchTodasPorObra(String obraId) {
    // database.watch() re-emite automáticamente cuando cambia cualquier fila
    // de solicitudes_autorizacion para esta obra — tanto por una escritura
    // local como por una fila que PowerSync acaba de sincronizar desde el
    // servidor (otro chofer u otro administrativo). Así la bandeja se
    // actualiza sola, sin necesidad de invalidar el provider a mano.
    return database
        .watch(
          '''
          SELECT * FROM solicitudes_autorizacion
          WHERE obra_id = ?
          ORDER BY creado_en DESC
          ''',
          parameters: [obraId],
        )
        .map(
          (filas) => filas
              .map((fila) => SolicitudAutorizacion.fromJson(_filaAJson(fila)))
              .toList(),
        );
  }

  @override
  Future<void> resolver({
    required String solicitudId,
    required EstadoSolicitud estado,
    String? comentario,
    double? litrosAutorizados,
  }) async {
    // Mismo criterio que backend/src/services/solicitudAutorizacion.service.ts:
    // si se autoriza sin especificar litrosAutorizados, se entiende que se
    // autoriza el total solicitado originalmente.
    double? litrosAutorizadosFinal = litrosAutorizados;
    if (estado == EstadoSolicitud.autorizado &&
        litrosAutorizadosFinal == null) {
      final fila = await database.getOptional(
        'SELECT litros_solicitados FROM solicitudes_autorizacion WHERE id = ?',
        [solicitudId],
      );
      litrosAutorizadosFinal = (fila?['litros_solicitados'] as num?)
          ?.toDouble();
    }

    await database.execute(
      '''
      UPDATE solicitudes_autorizacion
      SET estado = ?, litros_autorizados = ?, comentario = COALESCE(?, comentario)
      WHERE id = ?
      ''',
      [estado.toDb(), litrosAutorizadosFinal, comentario, solicitudId],
    );
  }

  Map<String, dynamic> _filaAJson(Map<String, dynamic> fila) => {
    'id': fila['id'],
    'chofer_id': fila['chofer_id'],
    'vehiculo_id': fila['vehiculo_id'],
    'obra_id': fila['obra_id'],
    'litros_solicitados': fila['litros_solicitados'],
    'litros_autorizados': fila['litros_autorizados'],
    'comentario': fila['comentario'],
    'estado': fila['estado'],
    'resuelto_por': fila['resuelto_por'],
    'resuelto_en': fila['resuelto_en'],
    'creado_en': fila['creado_en'],
    'creado_offline': fila['creado_offline'] == 1,
    'actividad': fila['actividad'],
    'responsable': fila['responsable'],
  };
}
