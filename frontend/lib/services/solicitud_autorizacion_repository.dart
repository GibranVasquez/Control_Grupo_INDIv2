import '../models/models.dart';

abstract class SolicitudAutorizacionRepository {
  /// Encolada localmente y confirmada al instante, sin esperar red (creado_offline = true hasta sincronizar).
  Future<void> crear(SolicitudAutorizacion solicitud);

  Future<List<SolicitudAutorizacion>> listarPorChofer(String choferId);

  Future<List<SolicitudAutorizacion>> listarPendientesPorObra(String obraId);

  /// [comentario] pasa a ser obligatorio en el llamador cuando se rechaza o se autoriza parcial
  /// (regla exacta pendiente de Fase 0 con backend).
  Future<void> resolver({
    required String solicitudId,
    required EstadoSolicitud estado,
    String? comentario,
  });
}
