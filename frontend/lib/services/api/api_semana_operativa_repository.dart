import '../../models/models.dart';
import '../semana_operativa_repository.dart';
import 'api_client.dart';

/// Decisión de transporte: 100% API REST directa, sin PowerSync.
///
/// `semanas_operativas` (y `fondo_semanal`) deliberadamente NO están en
/// backend/powersync/config/sync-config.yaml todavía (ver comentario en esa
/// sección del archivo: "no estaban en el alcance pedido"). No hay bucket
/// que las replique al dispositivo, así que no hay tabla local de PowerSync
/// de la cual leer/escribir: toda esta entidad depende de tener señal.
class ApiSemanaOperativaRepository implements SemanaOperativaRepository {
  ApiSemanaOperativaRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<SemanaOperativa> obtenerActual({String? obraId}) async {
    final respuesta = await apiClient.dio.get<Map<String, dynamic>>(
      '/semanas-operativas/actual',
      queryParameters: obraId == null ? null : {'obra_id': obraId},
    );
    return SemanaOperativa.fromJson(respuesta.data!['semana'] as Map<String, dynamic>);
  }

  @override
  Future<void> cerrar(String semanaId) async {
    await apiClient.dio.put('/semanas-operativas/$semanaId/cerrar');
  }
}
