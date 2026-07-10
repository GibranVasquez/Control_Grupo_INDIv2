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

  Future<void> actualizarActivo(String perfilId, bool activo);
}
