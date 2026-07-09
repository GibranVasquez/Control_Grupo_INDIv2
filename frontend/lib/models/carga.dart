import 'enums.dart';

class Carga {
  const Carga({
    required this.id,
    required this.solicitudId,
    required this.choferId,
    required this.vehiculoId,
    required this.obraId,
    required this.litros,
    required this.precioPorLitro,
    required this.montoTotal,
    required this.kmActual,
    this.kmAnterior,
    this.rendimientoKmL,
    this.alertaRendimiento,
    this.fotoTicketUrl,
    required this.fechaCarga,
    required this.creadoOffline,
    this.sincronizadoEn,
  });

  final String id;
  final String solicitudId;
  final String choferId;
  final String vehiculoId;
  final String obraId;
  final double litros;
  final double precioPorLitro;
  final double montoTotal;
  final int kmActual;
  final int? kmAnterior;

  /// Calculado por el backend a partir de km recorridos / litros cargados.
  final double? rendimientoKmL;
  final AlertaRendimiento? alertaRendimiento;

  /// Nulo mientras la foto sigue solo en el dispositivo, sin subir todavía.
  final String? fotoTicketUrl;
  final DateTime fechaCarga;
  final bool creadoOffline;
  final DateTime? sincronizadoEn;

  factory Carga.fromJson(Map<String, dynamic> json) => Carga(
        id: json['id'] as String,
        solicitudId: json['solicitud_id'] as String,
        choferId: json['chofer_id'] as String,
        vehiculoId: json['vehiculo_id'] as String,
        obraId: json['obra_id'] as String,
        litros: (json['litros'] as num).toDouble(),
        precioPorLitro: (json['precio_por_litro'] as num).toDouble(),
        montoTotal: (json['monto_total'] as num).toDouble(),
        kmActual: json['km_actual'] as int,
        kmAnterior: json['km_anterior'] as int?,
        rendimientoKmL: (json['rendimiento_km_l'] as num?)?.toDouble(),
        alertaRendimiento: json['alerta_rendimiento'] == null
            ? null
            : AlertaRendimiento.fromDb(json['alerta_rendimiento'] as String),
        fotoTicketUrl: json['foto_ticket_url'] as String?,
        fechaCarga: DateTime.parse(json['fecha_carga'] as String),
        creadoOffline: json['creado_offline'] as bool,
        sincronizadoEn: json['sincronizado_en'] == null
            ? null
            : DateTime.parse(json['sincronizado_en'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'solicitud_id': solicitudId,
        'chofer_id': choferId,
        'vehiculo_id': vehiculoId,
        'obra_id': obraId,
        'litros': litros,
        'precio_por_litro': precioPorLitro,
        'monto_total': montoTotal,
        'km_actual': kmActual,
        'km_anterior': kmAnterior,
        'rendimiento_km_l': rendimientoKmL,
        'alerta_rendimiento': alertaRendimiento?.toDb(),
        'foto_ticket_url': fotoTicketUrl,
        'fecha_carga': fechaCarga.toIso8601String(),
        'creado_offline': creadoOffline,
        'sincronizado_en': sincronizadoEn?.toIso8601String(),
      };
}
