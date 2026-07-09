class Obra {
  const Obra({
    required this.id,
    required this.nombre,
    this.ubicacion,
    required this.estado,
    this.fechaInicio,
    this.fechaFin,
  });

  final String id;
  final String nombre;
  final String? ubicacion;

  /// p.ej. "activa" / "finalizada" — valores exactos pendientes de confirmar con backend.
  final String estado;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  factory Obra.fromJson(Map<String, dynamic> json) => Obra(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        ubicacion: json['ubicacion'] as String?,
        estado: json['estado'] as String,
        fechaInicio: json['fecha_inicio'] == null
            ? null
            : DateTime.parse(json['fecha_inicio'] as String),
        fechaFin: json['fecha_fin'] == null ? null : DateTime.parse(json['fecha_fin'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'ubicacion': ubicacion,
        'estado': estado,
        'fecha_inicio': fechaInicio?.toIso8601String(),
        'fecha_fin': fechaFin?.toIso8601String(),
      };
}
