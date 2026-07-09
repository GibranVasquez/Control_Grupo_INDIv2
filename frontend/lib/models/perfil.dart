import 'enums.dart';

class Perfil {
  const Perfil({
    required this.id,
    required this.authUserId,
    required this.numeroEmpleado,
    required this.nombreCompleto,
    required this.rol,
    this.obraId,
    required this.activo,
  });

  final String id;
  final String authUserId;
  final String numeroEmpleado;
  final String nombreCompleto;
  final RolUsuario rol;

  /// Nulo para finanzas, que no está atado a una sola obra.
  final String? obraId;
  final bool activo;

  factory Perfil.fromJson(Map<String, dynamic> json) => Perfil(
        id: json['id'] as String,
        authUserId: json['auth_user_id'] as String,
        numeroEmpleado: json['numero_empleado'] as String,
        nombreCompleto: json['nombre_completo'] as String,
        rol: RolUsuario.fromDb(json['rol'] as String),
        obraId: json['obra_id'] as String?,
        activo: json['activo'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'auth_user_id': authUserId,
        'numero_empleado': numeroEmpleado,
        'nombre_completo': nombreCompleto,
        'rol': rol.toDb(),
        'obra_id': obraId,
        'activo': activo,
      };
}
