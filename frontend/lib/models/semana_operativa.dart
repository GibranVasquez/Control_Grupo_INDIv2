/// Periodo semanal que finanzas cierra al terminar la semana (Fase 5).
/// Campos provisionales — pendiente de confirmar con backend en Fase 0.
class SemanaOperativa {
  const SemanaOperativa({
    required this.id,
    required this.periodoInicio,
    required this.periodoFin,
    required this.estado,
  });

  final String id;
  final DateTime periodoInicio;
  final DateTime periodoFin;

  /// "abierta" / "cerrada".
  final String estado;

  bool get cerrada => estado == 'cerrada';

  factory SemanaOperativa.fromJson(Map<String, dynamic> json) => SemanaOperativa(
        id: json['id'] as String,
        periodoInicio: DateTime.parse(json['periodo_inicio'] as String),
        periodoFin: DateTime.parse(json['periodo_fin'] as String),
        estado: json['estado'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'periodo_inicio': periodoInicio.toIso8601String(),
        'periodo_fin': periodoFin.toIso8601String(),
        'estado': estado,
      };
}
