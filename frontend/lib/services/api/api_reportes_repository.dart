import '../../models/models.dart';
import '../reportes_repository.dart';
import 'api_client.dart';

/// Decisión de transporte: 100% API REST directa, sin PowerSync.
///
/// Las vistas de reportes (`vista_concentrado_cargas`,
/// `vista_resumen_financiero_semanal`, `vista_resumen_financiero_consolidado`,
/// `vista_consumo_vehiculo_semanal`) no son replicables por WAL lógico
/// (PowerSync sincroniza tablas, no vistas — ver
/// backend/powersync/POWERSYNC.md, sección "No incluidas todavía"). Esta
/// entidad siempre necesita señal; no tiene sentido offline.
class ApiReportesRepository implements ReportesRepository {
  ApiReportesRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<VistaConcentradoCargas>> concentradoCargas({
    required String obraId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final respuesta = await apiClient.dio.get<Map<String, dynamic>>(
      '/reportes/concentrado-cargas',
      queryParameters: {
        'obra_id': obraId,
        if (desde != null) 'desde': desde.toIso8601String(),
        if (hasta != null) 'hasta': hasta.toIso8601String(),
      },
    );
    final filas = respuesta.data!['cargas'] as List<dynamic>;
    return filas
        .map((fila) => VistaConcentradoCargas.fromJson(fila as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<VistaResumenFinancieroSemanal>> resumenFinancieroSemanal({
    required String obraId,
  }) async {
    final respuesta = await apiClient.dio.get<Map<String, dynamic>>(
      '/reportes/resumen-financiero-semanal',
      queryParameters: {'obra_id': obraId},
    );
    final filas = respuesta.data!['semanas'] as List<dynamic>;
    return filas
        .map((fila) => VistaResumenFinancieroSemanal.fromJson(fila as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<VistaResumenFinancieroSemanal>> resumenFinancieroConsolidado() async {
    final respuesta =
        await apiClient.dio.get<Map<String, dynamic>>('/reportes/resumen-financiero-consolidado');
    final filas = respuesta.data!['semanas'] as List<dynamic>;
    return filas
        .map((fila) => VistaResumenFinancieroSemanal.fromJson(fila as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<VistaConsumoVehiculoSemanal> consumoSemanalDeVehiculo(String vehiculoId) async {
    final respuesta = await apiClient.dio
        .get<Map<String, dynamic>>('/reportes/consumo-vehiculo-semanal/$vehiculoId');
    return VistaConsumoVehiculoSemanal.fromJson(respuesta.data!['consumo'] as Map<String, dynamic>);
  }
}
