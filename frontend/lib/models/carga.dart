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
    this.kmActual,
    this.kmAnterior,
    this.rendimientoKmL,
    this.horasActual,
    this.horasAnterior,
    this.rendimientoLH,
    this.alertaRendimiento,
    this.fotoTicketUrl,
    this.evidenciaLegible,
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

  /// Nulo cuando la unidad es maquinaria pesada y no usa kilometraje (usa [horasActual]).
  final int? kmActual;
  final int? kmAnterior;

  /// Calculado por el backend a partir de km recorridos / litros cargados.
  /// Solo aplica a vehículos con kilometraje; nulo para maquinaria pesada.
  final double? rendimientoKmL;

  /// Horómetro actual de la unidad. Solo aplica a maquinaria pesada; nulo para vehículos.
  final int? horasActual;

  /// Horómetro registrado en la carga previa. Solo aplica a maquinaria pesada.
  final int? horasAnterior;

  /// Rendimiento calculado por el backend en litros por hora (L/h) a partir de
  /// horas transcurridas / litros cargados. Solo aplica a maquinaria pesada.
  final double? rendimientoLH;

  final AlertaRendimiento? alertaRendimiento;

  /// Nulo mientras la foto sigue solo en el dispositivo, sin subir todavía.
  final String? fotoTicketUrl;

  /// Solo para Maquinaria: si el chofer confirmó que el medidor/número se
  /// alcanza a leer en las fotos de evidencia. Nulo para Vehículo (no aplica).
  final bool? evidenciaLegible;
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
        kmActual: json['km_actual'] as int?,
        kmAnterior: json['km_anterior'] as int?,
        rendimientoKmL: (json['rendimiento_km_l'] as num?)?.toDouble(),
        horasActual: json['horas_actual'] as int?,
        horasAnterior: json['horas_anterior'] as int?,
        rendimientoLH: (json['rendimiento_l_h'] as num?)?.toDouble(),
        alertaRendimiento: json['alerta_rendimiento'] == null
            ? null
            : AlertaRendimiento.fromDb(json['alerta_rendimiento'] as String),
        fotoTicketUrl: json['foto_ticket_url'] as String?,
        evidenciaLegible: json['evidencia_legible'] as bool?,
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
        'horas_actual': horasActual,
        'horas_anterior': horasAnterior,
        'rendimiento_l_h': rendimientoLH,
        'alerta_rendimiento': alertaRendimiento?.toDb(),
        'foto_ticket_url': fotoTicketUrl,
        'evidencia_legible': evidenciaLegible,
        'fecha_carga': fechaCarga.toIso8601String(),
        'creado_offline': creadoOffline,
        'sincronizado_en': sincronizadoEn?.toIso8601String(),
      };
}
