import 'package:powersync/powersync.dart';

import '../../models/models.dart';
import '../api/api_client.dart';
import '../precio_combustible_repository.dart';

/// Decisión de transporte para `precios_combustible`:
///
/// - Lecturas ([obtenerVigente], [listarHistorico]): PowerSync local.
///   `precios_combustible_catalogo` es un bucket global sin filtro por rol
///   ni obra (ver sync-config.yaml), así que cualquier usuario autenticado
///   ya tiene el catálogo completo replicado. El chofer lo necesita sin red
///   para poder estimar el importe de una solicitud/carga offline.
/// - Escritura ([crear]): API REST directa. Alta de un nuevo precio vigente
///   es una acción exclusiva de finanzas, hecha desde oficina; no es un caso
///   offline-crítico y evita tener que enseñarle a powersync_client.dart a
///   subir cambios de esta tabla.
class PowerSyncPrecioCombustibleRepository implements PrecioCombustibleRepository {
  PowerSyncPrecioCombustibleRepository({required this.database, required this.apiClient});

  final PowerSyncDatabase database;
  final ApiClient apiClient;

  @override
  Future<PrecioCombustible> obtenerVigente(TipoCombustible tipo) async {
    final fila = await database.getOptional(
      '''
      SELECT * FROM precios_combustible
      WHERE tipo_combustible = ? AND vigente_desde <= date('now')
      ORDER BY vigente_desde DESC
      LIMIT 1
      ''',
      [tipo.toDb()],
    );
    if (fila == null) {
      throw StateError('No hay un precio vigente para ${tipo.toDb()} en el catálogo local.');
    }
    return PrecioCombustible.fromJson(_filaAJson(fila));
  }

  @override
  Future<List<PrecioCombustible>> listarHistorico(TipoCombustible tipo) async {
    final filas = await database.getAll(
      'SELECT * FROM precios_combustible WHERE tipo_combustible = ? ORDER BY vigente_desde DESC',
      [tipo.toDb()],
    );
    return filas.map((fila) => PrecioCombustible.fromJson(_filaAJson(fila))).toList();
  }

  @override
  Future<void> crear(PrecioCombustible precio) async {
    await apiClient.dio.post('/precios-combustible', data: {
      'tipo_combustible': precio.tipoCombustible.toDb(),
      'precio_por_litro': precio.precioPorLitro,
      'vigente_desde': precio.vigenteDesde.toIso8601String(),
    });
  }

  Map<String, dynamic> _filaAJson(Map<String, dynamic> fila) => {
        'id': fila['id'],
        'tipo_combustible': fila['tipo_combustible'],
        'precio_por_litro': fila['precio_por_litro'],
        'vigente_desde': fila['vigente_desde'],
      };
}
