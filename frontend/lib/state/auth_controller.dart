import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'session_provider.dart';

/// Convención de correo para Supabase Auth a partir del número de empleado.
/// Pendiente de confirmar con backend en Fase 0 (podría ser SSO/OIDC en su lugar).
String _correoDesdeNumeroEmpleado(String numeroEmpleado) => '$numeroEmpleado@indi.internal';

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> iniciarSesion({
    required String numeroEmpleado,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(supabaseClientProvider);
      await client.auth.signInWithPassword(
        email: _correoDesdeNumeroEmpleado(numeroEmpleado),
        password: password,
      );
      final perfil = await ref.read(perfilRepositoryProvider).obtenerPerfilActual();
      ref.read(sesionProvider.notifier).iniciarSesion(perfil);
    });
  }

  Future<void> cerrarSesion() async {
    await ref.read(supabaseClientProvider).auth.signOut();
    ref.read(sesionProvider.notifier).cerrarSesion();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AsyncValue<void>>(
  AuthController.new,
);
