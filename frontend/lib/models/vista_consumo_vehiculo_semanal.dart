/// Fila de la vista `vista_consumo_vehiculo_semanal` — cuánto lleva consumido un vehículo
/// en la semana en curso, para avisar antes de solicitar si ya se acerca al tope.
/// Columnas y nombres exactos pendientes de confirmar con backend en Fase 0.
class VistaConsumoVehiculoSemanal {
  const VistaConsumoVehiculoSemanal({
    required this.vehiculoId,
    required this.litrosConsumidos,
    required this.topeLitrosSemanal,
  });

  final String vehiculoId;
  final double litrosConsumidos;
  final double topeLitrosSemanal;

  double get litrosDisponibles => topeLitrosSemanal - litrosConsumidos;

  factory VistaConsumoVehiculoSemanal.fromJson(Map<String, dynamic> json) =>
      VistaConsumoVehiculoSemanal(
        vehiculoId: json['vehiculo_id'] as String,
        litrosConsumidos: (json['litros_consumidos'] as num).toDouble(),
        topeLitrosSemanal: (json['tope_litros_semanal'] as num).toDouble(),
      );
}
