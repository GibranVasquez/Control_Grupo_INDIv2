import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/perfil_repository.dart';
import '../services/supabase/supabase_perfil_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final perfilRepositoryProvider = Provider<PerfilRepository>((ref) {
  return SupabasePerfilRepository(ref.watch(supabaseClientProvider));
});
