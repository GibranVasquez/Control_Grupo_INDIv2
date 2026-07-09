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
    required this.km,
    required this.litros,
    this.rendimientoKmL,
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
  final int km;
  final double litros;
  final double? rendimientoKmL;
  final double precioPorLitro;
  final TipoCombustible tipoCombustible;
  final double importe;
  final String? fotoTicketUrl;
  final AlertaRendimiento? alertaRendimiento;

  bool get ticketPendiente => fotoTicketUrl == null;

  factory VistaConcentradoCargas.fromJson(Map<String, dynamic> json) => VistaConcentradoCargas(
        cargaId: json['carga_id'] as String,
        fecha: DateTime.parse(json['fecha'] as String),
        responsable: json['responsable'] as String,
        vehiculoDescripcion: json['vehiculo_descripcion'] as String,
        placa: json['placa'] as String,
        km: json['km'] as int,
        litros: (json['litros'] as num).toDouble(),
        rendimientoKmL: (json['rendimiento_km_l'] as num?)?.toDouble(),
        precioPorLitro: (json['precio_por_litro'] as num).toDouble(),
        tipoCombustible: TipoCombustible.fromDb(json['tipo_combustible'] as String),
        importe: (json['importe'] as num).toDouble(),
        fotoTicketUrl: json['foto_ticket_url'] as String?,
        alertaRendimiento: json['alerta_rendimiento'] == null
            ? null
            : AlertaRendimiento.fromDb(json['alerta_rendimiento'] as String),
      );
}
