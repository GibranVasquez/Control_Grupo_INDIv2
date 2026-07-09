import 'enums.dart';

class SolicitudAutorizacion {
  const SolicitudAutorizacion({
    required this.id,
    required this.choferId,
    required this.vehiculoId,
    required this.obraId,
    required this.litrosSolicitados,
    this.litrosAutorizados,
    this.comentario,
    required this.estado,
    this.resueltoPor,
    this.resueltoEn,
    required this.creadoEn,
    required this.creadoOffline,
  });

  final String id;
  final String choferId;
  final String vehiculoId;
  final String obraId;
  final double litrosSolicitados;

  /// Distinto de litrosSolicitados cuando el administrativo ajusta la cantidad al autorizar.
  final double? litrosAutorizados;

  /// Obligatorio en el flujo cuando litrosSolicitados excede el tope semanal del vehículo.
  final String? comentario;
  final EstadoSolicitud estado;
  final String? resueltoPor;
  final DateTime? resueltoEn;
  final DateTime creadoEn;

  /// true mientras la solicitud fue creada sin conexión y no se ha sincronizado.
  final bool creadoOffline;

  factory SolicitudAutorizacion.fromJson(Map<String, dynamic> json) => SolicitudAutorizacion(
        id: json['id'] as String,
        choferId: json['chofer_id'] as String,
        vehiculoId: json['vehiculo_id'] as String,
        obraId: json['obra_id'] as String,
        litrosSolicitados: (json['litros_solicitados'] as num).toDouble(),
        litrosAutorizados: (json['litros_autorizados'] as num?)?.toDouble(),
        comentario: json['comentario'] as String?,
        estado: EstadoSolicitud.fromDb(json['estado'] as String),
        resueltoPor: json['resuelto_por'] as String?,
        resueltoEn:
            json['resuelto_en'] == null ? null : DateTime.parse(json['resuelto_en'] as String),
        creadoEn: DateTime.parse(json['creado_en'] as String),
        creadoOffline: json['creado_offline'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'chofer_id': choferId,
        'vehiculo_id': vehiculoId,
        'obra_id': obraId,
        'litros_solicitados': litrosSolicitados,
        'litros_autorizados': litrosAutorizados,
        'comentario': comentario,
        'estado': estado.toDb(),
        'resuelto_por': resueltoPor,
        'resuelto_en': resueltoEn?.toIso8601String(),
        'creado_en': creadoEn.toIso8601String(),
        'creado_offline': creadoOffline,
      };
}
