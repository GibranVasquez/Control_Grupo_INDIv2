import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../perfil_repository.dart';

class SupabasePerfilRepository implements PerfilRepository {
  SupabasePerfilRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Perfil> obtenerPerfilActual() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('No hay sesión activa en Supabase Auth.');
    }
    final fila = await _client.from('perfiles').select().eq('auth_user_id', uid).single();
    return Perfil.fromJson(fila);
  }

  @override
  Future<List<Perfil>> listarPorObra(String obraId) async {
    final filas = await _client.from('perfiles').select().eq('obra_id', obraId);
    return filas.map(Perfil.fromJson).toList();
  }

  @override
  Future<void> actualizarActivo(String perfilId, bool activo) async {
    await _client.from('perfiles').update({'activo': activo}).eq('id', perfilId);
  }
}
