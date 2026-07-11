import 'enums.dart';

/// Fila de la vista `vista_concentrado_cargas` — reemplaza la hoja "Concentrado de cargas".
/// Columnas y nombres exactos pendientes de confirmar con backend en Fase 0.
class VistaConcentradoCargas {
  const VistaConcentradoCargas({
    required this.cargaId,
    required this.fecha,
    required this.responsable,
    required this.vehiculoDescripcion,
    required this.placa,
    this.tipoUnidad = TipoUnidad.vehiculo,
    this.km,
    required this.litros,
    this.rendimientoKmL,
    this.horasActual,
    this.rendimientoLH,
    required this.precioPorLitro,
    required this.tipoCombustible,
    required this.importe,
    this.fotoTicketUrl,
    this.alertaRendimiento,
  });

  final String cargaId;
  final DateTime fecha;
  final String responsable;
  final String vehiculoDescripcion;
  final String placa;
  final TipoUnidad tipoUnidad;

  /// Nulo cuando la carga es de maquinaria (usa [horasActual] en su lugar).
  final int? km;
  final double litros;
  final double? rendimientoKmL;

  /// Horómetro actual. Solo aplica a maquinaria pesada; nulo para vehículos con kilometraje.
  final int? horasActual;

  /// Rendimiento en litros por hora. Solo aplica a maquinaria pesada.
  final double? rendimientoLH;
  final double precioPorLitro;
  final TipoCombustible tipoCombustible;
  final double importe;
  final String? fotoTicketUrl;
  final AlertaRendimiento? alertaRendimiento;

  bool get esMaquinaria => tipoUnidad == TipoUnidad.maquinaria;

  bool get ticketPendiente => fotoTicketUrl == null;

  factory VistaConcentradoCargas.fromJson(Map<String, dynamic> json) => VistaConcentradoCargas(
        cargaId: json['carga_id'] as String,
        fecha: DateTime.parse(json['fecha'] as String),
        responsable: json['responsable'] as String,
        vehiculoDescripcion: json['vehiculo_descripcion'] as String,
        placa: json['placa'] as String,
        tipoUnidad: json['tipo_unidad'] == null
            ? TipoUnidad.vehiculo
            : TipoUnidad.fromDb(json['tipo_unidad'] as String),
        km: json['km'] as int?,
        litros: (json['litros'] as num).toDouble(),
        rendimientoKmL: (json['rendimiento_km_l'] as num?)?.toDouble(),
        horasActual: json['horas_actual'] as int?,
        rendimientoLH: (json['rendimiento_l_h'] as num?)?.toDouble(),
        precioPorLitro: (json['precio_por_litro'] as num).toDouble(),
        tipoCombustible: TipoCombustible.fromDb(json['tipo_combustible'] as String),
        importe: (json['importe'] as num).toDouble(),
        fotoTicketUrl: json['foto_ticket_url'] as String?,
        alertaRendimiento: json['alerta_rendimiento'] == null
            ? null
            : AlertaRendimiento.fromDb(json['alerta_rendimiento'] as String),
      );
}
