import 'package:dio/dio.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../api/api_client.dart';
import '../carga_repository.dart';

/// Decisión de transporte para `cargas`:
///
/// - [crear], [listarPorChofer], [listarPorObra]: 100% PowerSync local. Es,
///   junto con `solicitudes_autorizacion`, la otra entidad offline-first
///   explícita del alcance de esta migración: el chofer registra la carga
///   en campo, sin señal, y PowerSync la sube sola (ver powersync_client.dart,
///   que traduce el insert local a `POST /cargas`).
/// - [subirFotoTicket]: API REST directa (`POST /cargas/:id/foto-ticket`,
///   multipart). No puede pasar por la cola de PowerSync: esa cola solo
///   sabe subir cambios de columnas (JSON), no archivos binarios. Por
///   diseño requiere conexión al momento de llamarse (igual que ya
///   documentaba el comentario original de la interfaz: "sube la foto del
///   ticket guardada localmente").
///
/// [crear] siempre genera su propio id (uuid v4), ignorando cualquier valor
/// en `carga.id`; ese mismo id se manda al backend al subir el cambio (ver
/// powersync_client.dart) y `carga.service.ts` lo usa como id real — mismo
/// criterio que powersync_solicitud_autorizacion_repository.dart.
class PowerSyncCargaRepository implements CargaRepository {
  PowerSyncCargaRepository({required this.database, required this.apiClient});

  final PowerSyncDatabase database;
  final ApiClient apiClient;

  static const _uuid = Uuid();

  @override
  Future<String> crear(Carga carga) async {
    final id = _uuid.v4();
    await database.execute(
      '''
      INSERT INTO cargas
        (id, solicitud_id, chofer_id, vehiculo_id, obra_id, litros, precio_por_litro,
         monto_total, km_actual, km_anterior, horas_actual, horas_anterior,
         fecha_carga, creado_offline)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        carga.solicitudId,
        carga.choferId,
        carga.vehiculoId,
        carga.obraId,
        carga.litros,
        carga.precioPorLitro,
        // monto_total es columna generada en Postgres (litros * precio_por_litro);
        // localmente no hay trigger que la calcule, así que se refleja aquí
        // solo para que la UI tenga un valor razonable hasta que llegue la
        // fila real sincronizada. No se envía al backend (ver powersync_client.dart).
        carga.litros * carga.precioPorLitro,
        carga.kmActual,
        carga.kmAnterior,
        carga.horasActual,
        carga.horasAnterior,
        carga.fechaCarga.toIso8601String(),
        carga.creadoOffline ? 1 : 0,
      ],
    );
    return id;
  }

  @override
  Future<Carga?> obtenerUltimaPorVehiculo(String vehiculoId) async {
    final fila = await database.getOptional(
      'SELECT * FROM cargas WHERE vehiculo_id = ? ORDER BY fecha_carga DESC LIMIT 1',
      [vehiculoId],
    );
    if (fila == null) return null;
    return Carga.fromJson(_filaAJson(fila));
  }

  @override
  Future<List<Carga>> listarPorChofer(String choferId) async {
    final filas = await database.getAll(
      'SELECT * FROM cargas WHERE chofer_id = ? ORDER BY fecha_carga DESC',
      [choferId],
    );
    return filas.map((fila) => Carga.fromJson(_filaAJson(fila))).toList();
  }

  @override
  Future<List<Carga>> listarPorObra(String obraId) async {
    final filas = await database.getAll(
      'SELECT * FROM cargas WHERE obra_id = ? ORDER BY fecha_carga DESC',
      [obraId],
    );
    return filas.map((fila) => Carga.fromJson(_filaAJson(fila))).toList();
  }

  @override
  Future<String> subirFotoTicket(String cargaId, String rutaLocal) async {
    final formData = FormData.fromMap({
      'foto': await MultipartFile.fromFile(rutaLocal),
    });
    final respuesta = await apiClient.dio.post<Map<String, dynamic>>(
      '/cargas/$cargaId/foto-ticket',
      data: formData,
    );
    return respuesta.data!['carga']['foto_ticket_url'] as String;
  }

  Map<String, dynamic> _filaAJson(Map<String, dynamic> fila) => {
        'id': fila['id'],
        'solicitud_id': fila['solicitud_id'],
        'chofer_id': fila['chofer_id'],
        'vehiculo_id': fila['vehiculo_id'],
        'obra_id': fila['obra_id'],
        'litros': fila['litros'],
        'precio_por_litro': fila['precio_por_litro'],
        'monto_total': fila['monto_total'],
        'km_actual': (fila['km_actual'] as num?)?.toInt(),
        'km_anterior': (fila['km_anterior'] as num?)?.toInt(),
        'rendimiento_km_l': fila['rendimiento_km_l'],
        'horas_actual': (fila['horas_actual'] as num?)?.toInt(),
        'horas_anterior': (fila['horas_anterior'] as num?)?.toInt(),
        'rendimiento_l_h': fila['rendimiento_l_h'],
        'alerta_rendimiento': fila['alerta_rendimiento'],
        'foto_ticket_url': fila['foto_ticket_url'],
        'fecha_carga': fila['fecha_carga'],
        'creado_offline': fila['creado_offline'] == 1,
        'sincronizado_en': fila['sincronizado_en'],
      };
}
