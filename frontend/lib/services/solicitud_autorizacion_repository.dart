import '../models/models.dart';

abstract class SolicitudAutorizacionRepository {
  /// Encolada localmente y confirmada al instante, sin esperar red (creado_offline = true hasta sincronizar).
  Future<void> crear(SolicitudAutorizacion solicitud);

  Future<List<SolicitudAutorizacion>> listarPorChofer(String choferId);

  Future<List<SolicitudAutorizacion>> listarPendientesPorObra(String obraId);

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

/// Implementación simulada mientras no exista integración real con el backend.
///
/// Empaqueta [comentario] y [litrosAutorizados] en un mismo payload para dejar
/// listo el contrato que se enviará por red en cuanto Fase 0 confirme el endpoint.
class SolicitudAutorizacionRepositoryFake implements SolicitudAutorizacionRepository {
  @override
  Future<void> crear(SolicitudAutorizacion solicitud) async {
    // TODO: persistir localmente / encolar para sincronización offline.
  }

  @override
  Future<List<SolicitudAutorizacion>> listarPorChofer(String choferId) async {
    // TODO: consultar almacenamiento local / backend.
    return [];
  }

  @override
  Future<List<SolicitudAutorizacion>> listarPendientesPorObra(String obraId) async {
    // TODO: consultar almacenamiento local / backend.
    return [];
  }

  @override
  Future<void> resolver({
    required String solicitudId,
    required EstadoSolicitud estado,
    String? comentario,
    double? litrosAutorizados,
  }) async {
    final payload = <String, dynamic>{
      'solicitud_id': solicitudId,
      'estado': estado.toDb(),
      if (comentario != null && comentario.isNotEmpty) 'comentario': comentario,
      if (litrosAutorizados != null) 'litros_autorizados': litrosAutorizados,
    };

    // TODO: enviar `payload` al backend (PATCH/PUT solicitud + resolución).
    // Simulación temporal para no bloquear el flujo de UI mientras no hay red real.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print('resolver() payload simulado: $payload');
  }
}
