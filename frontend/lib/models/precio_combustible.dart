import 'enums.dart';

/// Precio vigente por tipo de combustible (Fase 5: gestión de precios, finanzas da de alta uno nuevo).
class PrecioCombustible {
  const PrecioCombustible({
    required this.id,
    required this.tipoCombustible,
    required this.precioPorLitro,
    required this.vigenteDesde,
  });

  final String id;
  final TipoCombustible tipoCombustible;
  final double precioPorLitro;
  final DateTime vigenteDesde;

  factory PrecioCombustible.fromJson(Map<String, dynamic> json) => PrecioCombustible(
        id: json['id'] as String,
        tipoCombustible: TipoCombustible.fromDb(json['tipo_combustible'] as String),
        precioPorLitro: (json['precio_por_litro'] as num).toDouble(),
        vigenteDesde: DateTime.parse(json['vigente_desde'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo_combustible': tipoCombustible.toDb(),
        'precio_por_litro': precioPorLitro,
        'vigente_desde': vigenteDesde.toIso8601String(),
      };
}
