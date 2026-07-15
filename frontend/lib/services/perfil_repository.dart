import '../models/models.dart';

abstract class PerfilRepository {
  /// Autentica contra la API propia (`POST /auth/login`) y deja lista la
  /// sesión (JWT persistido) para las siguientes llamadas, tanto REST como
  /// PowerSync. Extensión del contrato original: con Supabase, el login vivía
  /// en `SupabaseClient.auth` directamente y este repositorio solo leía el
  /// perfil ya autenticado; al no tener un `authClient` genérico equivalente,
  /// el login pasa a ser responsabilidad de esta interfaz.
  Future<Perfil> iniciarSesion({required String usuario, required String password});

  /// El perfil del usuario con sesión activa (`GET /auth/perfil-actual`).
  Future<Perfil> obtenerPerfilActual();

  Future<List<Perfil>> listarPorObra(String obraId);

  /// Todos los perfiles replicados localmente (solo finanzas los tiene todos —
  /// ver sync-config.yaml bucket `finanzas_global` — administrativo solo ve los
  /// de su propia obra vía [listarPorObra]).
  Future<List<Perfil>> listarTodos();

  Future<void> actualizarActivo(String perfilId, bool activo);

  /// Edición parcial de un chofer ya registrado (`PUT /perfiles/:id`). Solo
  /// administrativo/finanzas. Reemplaza la vieja alta manual (`POST
  /// /perfiles`, eliminada — el chofer ahora se autoregistra) y el viejo
  /// endpoint de asignación (`PUT /perfiles/:id/asignacion`, fusionado aquí).
  ///
  /// [obraId] es obligatorio en cada llamada aunque solo se quiera cambiar
  /// otro campo — el backend lo exige siempre, no solo cuando cambia. Los
  /// campos que se omitan conservan su valor actual (edición parcial real);
  /// `usuario`/password no son editables por este endpoint.
  Future<Perfil> actualizar({
    required String perfilId,
    required String obraId,
    String? nombreCompleto,
    String? correo,
    int? edad,
    String? area,
    String? vehiculoId,
  });

  /// Autoregistro público de chofer (`POST /auth/registro-chofer`), sin
  /// sesión previa: crea el perfil y, junto con él en la misma transacción
  /// del backend, su propia unidad (vehículo/maquinaria) ya enlazada vía
  /// `vehiculo_id` — cada chofer trae su unidad dedicada, no se elige de un
  /// catálogo compartido. No deja sesión iniciada (ver auth_controller.dart);
  /// el chofer entra después por [iniciarSesion]. Ver registro_chofer_page.dart.
  Future<Perfil> registrarChofer({
    required String nombreCompleto,
    required String usuario,
    required String password,
    required String obraId,
    required String placa,
    required String tipoUnidad,
    required String tipoCombustible,
    String? correo,
    int? edad,
    String? area,
  });

  /// Obras activas disponibles para el selector del formulario de registro
  /// (`GET /auth/obras-disponibles`, sin sesión previa).
  Future<List<ObraOpcion>> obrasDisponibles();
}

/// Versión mínima de [Obra] (solo id/nombre) para el selector del formulario
/// público de registro — no expone ubicación/estado/fechas.
class ObraOpcion {
  const ObraOpcion({required this.id, required this.nombre});

  final String id;
  final String nombre;

  factory ObraOpcion.fromJson(Map<String, dynamic> json) => ObraOpcion(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
      );
}
