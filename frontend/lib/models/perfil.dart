import 'enums.dart';

class Perfil {
  const Perfil({
    required this.id,
    required this.authUserId,
    required this.usuario,
    required this.nombreCompleto,
    required this.rol,
    this.correo,
    this.edad,
    this.obraId,
    this.vehiculoId,
    this.area,
    required this.activo,
  });

  final String id;
  final String authUserId;
  final String usuario;
  final String nombreCompleto;
  final RolUsuario rol;

  /// Correo estructurado (único, se normaliza a minúsculas en el backend).
  final String? correo;

  /// Edad estructurada.
  final int? edad;

  /// Nulo para finanzas, que no está atado a una sola obra.
  final String? obraId;

  /// Vehículo asignado al chofer; nulo para administrativo/finanzas.
  final String? vehiculoId;

  /// Área/departamento del perfil (informativo, opcional).
  final String? area;
  final bool activo;

  factory Perfil.fromJson(Map<String, dynamic> json) => Perfil(
        id: json['id'] as String,
        authUserId: json['auth_user_id'] as String,
        usuario: json['usuario'] as String,
        nombreCompleto: json['nombre_completo'] as String,
        rol: RolUsuario.fromDb(json['rol'] as String),
        correo: json['correo'] as String?,
        edad: json['edad'] as int?,
        obraId: json['obra_id'] as String?,
        vehiculoId: json['vehiculo_id'] as String?,
        area: json['area'] as String?,
        activo: json['activo'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'auth_user_id': authUserId,
        'usuario': usuario,
        'nombre_completo': nombreCompleto,
        'rol': rol.toDb(),
        'correo': correo,
        'edad': edad,
        'obra_id': obraId,
        'vehiculo_id': vehiculoId,
        'area': area,
        'activo': activo,
      };
}
