import 'package:powersync/powersync.dart';

import '../../models/models.dart';
import '../api/api_client.dart';
import '../vehiculo_repository.dart';

/// Decisión de transporte para `vehiculos`:
///
/// - Lecturas ([listarPorObra], [obtenerPorId]): PowerSync local. La tabla
///   ya está en sync-config.yaml para los dos roles (`chofer_obra_catalogo`,
///   `administrativo_global`), y el chofer la necesita sin
///   red para poder armar una solicitud de combustible offline (elegir su
///   vehículo, ver su tope semanal) — es justo el caso que offline-first
///   tiene que cubrir, aunque sea "catálogo" y no una escritura.
/// - Escrituras ([crear], [actualizar]): API REST directa. Son acciones
///   administrativas (solo rol `administrativo`), hechas normalmente desde
///   oficina con buena señal; no vale la pena la complejidad de encolarlas
///   en PowerSync (que además tendría que enseñarle al conector a subirlas,
///   ver powersync_client.dart) para un caso que no es offline-crítico. La
///   fila ya editada llega de vuelta al catálogo local en la siguiente
///   sincronización normal de PowerSync.
class PowerSyncVehiculoRepository implements VehiculoRepository {
  PowerSyncVehiculoRepository({required this.database, required this.apiClient});

  final PowerSyncDatabase database;
  final ApiClient apiClient;

  @override
  Future<List<Vehiculo>> listarPorObra(String obraId) async {
    final filas = await database.getAll(
      'SELECT * FROM vehiculos WHERE obra_id = ? ORDER BY placa ASC',
      [obraId],
    );
    return filas.map((fila) => Vehiculo.fromJson(_filaAJson(fila))).toList();
  }

  @override
  Future<Vehiculo> obtenerPorId(String vehiculoId) async {
    final fila = await database.getOptional('SELECT * FROM vehiculos WHERE id = ?', [vehiculoId]);
    if (fila == null) {
      throw StateError('Vehículo $vehiculoId no encontrado en el catálogo local.');
    }
    return Vehiculo.fromJson(_filaAJson(fila));
  }

  @override
  Future<void> crear(Vehiculo vehiculo) async {
    await apiClient.dio.post('/vehiculos', data: _vehiculoABody(vehiculo));
  }

  @override
  Future<void> actualizar(Vehiculo vehiculo) async {
    await apiClient.dio.put('/vehiculos/${vehiculo.id}', data: _vehiculoABody(vehiculo));
  }

  Map<String, dynamic> _vehiculoABody(Vehiculo vehiculo) => {
        'placa': vehiculo.placa,
        'marca': vehiculo.marca,
        'modelo': vehiculo.modelo,
        'anio': vehiculo.anio,
        'tipo_combustible': vehiculo.tipoCombustible.toDb(),
        'tope_litros_semanal': vehiculo.topeLitrosSemanal,
        'estado': vehiculo.estado,
        'tipo_unidad': vehiculo.tipoUnidad.toDb(),
      };

  Map<String, dynamic> _filaAJson(Map<String, dynamic> fila) => {
        'id': fila['id'],
        'placa': fila['placa'],
        'marca': fila['marca'],
        'modelo': fila['modelo'],
        'anio': fila['anio'],
        'tipo_combustible': fila['tipo_combustible'],
        'tope_litros_semanal': fila['tope_litros_semanal'],
        'obra_id': fila['obra_id'],
        'estado': fila['estado'],
        'tipo_unidad': fila['tipo_unidad'],
      };
}
