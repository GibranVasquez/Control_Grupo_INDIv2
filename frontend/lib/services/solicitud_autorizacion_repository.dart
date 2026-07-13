import '../models/models.dart';

abstract class SolicitudAutorizacionRepository {
  /// Encolada localmente y confirmada al instante, sin esperar red (creado_offline = true hasta sincronizar).
  Future<void> crear(SolicitudAutorizacion solicitud);

  Future<List<SolicitudAutorizacion>> listarPorChofer(String choferId);

  Future<List<SolicitudAutorizacion>> listarPendientesPorObra(String obraId);

  /// Todas las solicitudes de la obra (cualquier estado), más recientes
  /// primero, actualizándose en tiempo real conforme llegan nuevas
  /// solicitudes o cambia su estado (de este dispositivo o de cualquier
  /// otro, vía sincronización de PowerSync).
  Stream<List<SolicitudAutorizacion>> watchTodasPorObra(String obraId);

  /// Resuelve una solicitud como autorizada (total o parcial) o rechazada.
  ///
  /// [comentario] es obligatorio en el llamador cuando se rechaza o se autoriza parcial
  /// (regla exacta pendiente de confirmar con backend en Fase 0).
  ///
  /// [litrosAutorizados] permite autorizar una cantidad distinta a la solicitada
  /// (autorización parcial). Si es `null`, se entiende que se autoriza el total
  /// solicitado originalmente; el backend es quien decide el valor final persistido.
  Future<void> resolver({
    required String solicitudId,
    required EstadoSolicitud estado,
    String? comentario,
    double? litrosAutorizados,
  });
}
