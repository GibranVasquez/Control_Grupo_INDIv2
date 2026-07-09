import 'enums.dart';

class Vehiculo {
  const Vehiculo({
    required this.id,
    required this.placa,
    required this.marca,
    required this.modelo,
    this.anio,
    required this.tipoCombustible,
    required this.topeLitrosSemanal,
    required this.obraId,
    required this.estado,
    this.tipoUnidad = TipoUnidad.vehiculo,
  });

  final String id;
  final String placa;
  final String marca;
  final String modelo;
  final int? anio;
  final TipoCombustible tipoCombustible;
  final double topeLitrosSemanal;
  final String obraId;

  /// p.ej. "activo" / "inactivo" — valores exactos pendientes de confirmar con backend.
  final String estado;

  /// Vehículo se comprueba por km; maquinaria se comprueba por horas de operación (L/h).
  final TipoUnidad tipoUnidad;

  String get descripcion => '$marca $modelo';

  factory Vehiculo.fromJson(Map<String, dynamic> json) => Vehiculo(
        id: json['id'] as String,
        placa: json['placa'] as String,
        marca: json['marca'] as String,
        modelo: json['modelo'] as String,
        anio: json['anio'] as int?,
        tipoCombustible: TipoCombustible.fromDb(json['tipo_combustible'] as String),
        topeLitrosSemanal: (json['tope_litros_semanal'] as num).toDouble(),
        obraId: json['obra_id'] as String,
        estado: json['estado'] as String,
        tipoUnidad: json['tipo_unidad'] == null
            ? TipoUnidad.vehiculo
            : TipoUnidad.fromDb(json['tipo_unidad'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
        'tipo_combustible': tipoCombustible.toDb(),
        'tope_litros_semanal': topeLitrosSemanal,
        'obra_id': obraId,
        'estado': estado,
        'tipo_unidad': tipoUnidad.toDb(),
      };
}
