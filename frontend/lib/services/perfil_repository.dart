import '../models/models.dart';

abstract class PerfilRepository {
  /// Autentica contra la API propia (`POST /auth/login`) y deja lista la
  /// sesión (JWT persistido) para las siguientes llamadas, tanto REST como
  /// PowerSync. Extensión del contrato original: con Supabase, el login vivía
  /// en `SupabaseClient.auth` directamente y este repositorio solo leía el
  /// perfil ya autenticado; al no tener un `authClient` genérico equivalente,
  /// el login pasa a ser responsabilidad de esta interfaz.
  Future<Perfil> iniciarSesion({required String numeroEmpleado, required String password});

  /// El perfil del usuario con sesión activa (`GET /auth/perfil-actual`).
  Future<Perfil> obtenerPerfilActual();

  Future<List<Perfil>> listarPorObra(String obraId);

  /// Todos los perfiles replicados localmente (solo finanzas los tiene todos —
  /// ver sync-config.yaml bucket `finanzas_global` — administrativo solo ve los
  /// de su propia obra vía [listarPorObra]).
  Future<List<Perfil>> listarTodos();

  Future<void> actualizarActivo(String perfilId, bool activo);

  /// Alta de un chofer nuevo (`POST /perfiles`). Solo administrativo/finanzas.
  Future<Perfil> crear({
    required String nombreCompleto,
    required String numeroEmpleado,
    required String password,
    required String obraId,
    String? vehiculoId,
    String? area,
  });

  /// Autoregistro público de chofer (`POST /auth/registro-chofer`), sin
  /// sesión previa: crea el perfil ya activo (sin obra/vehículo asignados) y
  /// deja el JWT guardado, igual que [iniciarSesion]. Ver registro_chofer_page.dart.
  Future<Perfil> registrarChofer({
    required String nombreCompleto,
    required String numeroEmpleado,
    required String password,
    String? area,
  });
}
