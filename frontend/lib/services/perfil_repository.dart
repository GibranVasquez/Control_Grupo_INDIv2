import '../models/models.dart';

abstract class PerfilRepository {
  /// El perfil del usuario con sesión activa (perfiles.auth_user_id = auth.uid()).
  Future<Perfil> obtenerPerfilActual();

  Future<List<Perfil>> listarPorObra(String obraId);

  Future<void> actualizarActivo(String perfilId, bool activo);
}
