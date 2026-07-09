/// Rol del usuario, define qué rama de rutas ve (ver router/).
enum RolUsuario {
  chofer,
  administrativo,
  finanzas;

  static RolUsuario fromDb(String value) => values.firstWhere(
        (r) => r.name == value,
        orElse: () => throw ArgumentError('Rol desconocido: $value'),
      );

  String toDb() => name;
}

enum TipoCombustible {
  magna,
  premium,
  diesel;

  static TipoCombustible fromDb(String value) => values.firstWhere(
        (t) => t.name == value,
        orElse: () => throw ArgumentError('Tipo de combustible desconocido: $value'),
      );

  String toDb() => name;

  String get etiqueta => switch (this) {
        TipoCombustible.magna => 'Magna',
        TipoCombustible.premium => 'Premium',
        TipoCombustible.diesel => 'Diésel',
      };
}

/// Estado de una solicitud de autorización (login → solicita → admin resuelve → chofer carga).
enum EstadoSolicitud {
  pendiente,
  autorizado,
  rechazado,
  cargado;

  static EstadoSolicitud fromDb(String value) => values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Estado de solicitud desconocido: $value'),
      );

  String toDb() => name;
}

/// Tipo de unidad: vehículo (control por km) o maquinaria (control por horas de operación).
enum TipoUnidad {
  vehiculo,
  maquinaria;

  static TipoUnidad fromDb(String value) => values.firstWhere(
        (t) => t.name == value,
        orElse: () => throw ArgumentError('Tipo de unidad desconocido: $value'),
      );

  String toDb() => name;
}

/// Semáforo de rendimiento km/L calculado por el backend al comprobar una carga.
/// Umbrales de referencia (design/README.md): <3 o >15 => revisar, 3–6 => bajo, >6 => normal.
enum AlertaRendimiento {
  normal,
  bajo,
  revisar;

  static AlertaRendimiento fromDb(String value) => values.firstWhere(
        (a) => a.name == value,
        orElse: () => throw ArgumentError('Alerta de rendimiento desconocida: $value'),
      );

  String toDb() => name;
}
