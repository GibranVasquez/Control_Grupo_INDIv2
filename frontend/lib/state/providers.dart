import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/biometria_service.dart';
import '../services/credenciales_storage.dart';
import '../services/perfil_repository.dart';
import '../services/supabase/supabase_perfil_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final perfilRepositoryProvider = Provider<PerfilRepository>((ref) {
  return SupabasePerfilRepository(ref.watch(supabaseClientProvider));
});

final biometriaServiceProvider = Provider<BiometriaService>((ref) => BiometriaService());

final credencialesStorageProvider = Provider<CredencialesStorage>((ref) => const CredencialesStorage());

/// true solo si la plataforma es móvil, el dispositivo soporta biometría y ya hay una sesión
/// previa guardada (es decir, el usuario ya se registró/inició sesión antes en este dispositivo).
final puedeUsarBiometriaProvider = FutureProvider<bool>((ref) async {
  final servicio = ref.watch(biometriaServiceProvider);
  if (!servicio.soportadaEnPlataforma) return false;
  final credenciales = await ref.watch(credencialesStorageProvider).leer();
  if (credenciales == null) return false;
  return servicio.disponible();
});
