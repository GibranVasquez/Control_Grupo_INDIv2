import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dev/usuario_registrado.dart';
import '../models/models.dart';
import 'providers.dart';
import 'session_provider.dart';
import 'usuarios_registrados_provider.dart';

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
      // Primero se busca contra las altas hechas en register_page.dart (en memoria, sin backend).
      // Si hay match, entra sin tocar Supabase; si no, se intenta el login real contra Supabase Auth.
      final usuarioDemo = ref
          .read(usuariosRegistradosProvider.notifier)
          .buscarPorCredenciales(numeroEmpleado, password);

      if (usuarioDemo != null) {
        await _entrarComoUsuarioDemo(usuarioDemo, password);
        return;
      }

      final client = ref.read(supabaseClientProvider);
      await client.auth.signInWithPassword(
        email: _correoDesdeNumeroEmpleado(numeroEmpleado),
        password: password,
      );
      final perfil = await ref.read(perfilRepositoryProvider).obtenerPerfilActual();
      ref.read(usuarioActualDemoProvider.notifier).establecer(null);
      ref.read(sesionProvider.notifier).iniciarSesion(perfil);
      await ref
          .read(credencialesStorageProvider)
          .guardar(usuario: numeroEmpleado, password: password);
    });
  }

  /// Intenta reabrir sesión con las credenciales guardadas tras una autenticación biométrica
  /// exitosa. Regresa false si no hay credenciales guardadas o la biometría fue rechazada.
  Future<bool> iniciarSesionConBiometria() async {
    final credenciales = await ref.read(credencialesStorageProvider).leer();
    if (credenciales == null) return false;

    final autenticado = await ref.read(biometriaServiceProvider).autenticar();
    if (!autenticado) return false;

    await iniciarSesion(numeroEmpleado: credenciales.usuario, password: credenciales.password);
    return state.hasError == false;
  }

  Future<void> _entrarComoUsuarioDemo(UsuarioRegistrado usuarioDemo, String password) async {
    final perfil = Perfil(
      id: 'perfil-demo-${usuarioDemo.usuario}',
      authUserId: 'auth-demo-${usuarioDemo.usuario}',
      numeroEmpleado: usuarioDemo.usuario,
      nombreCompleto: usuarioDemo.nombreCompleto,
      rol: RolUsuario.chofer,
      obraId: usuarioDemo.obraId,
      activo: true,
    );
    ref.read(usuarioActualDemoProvider.notifier).establecer(usuarioDemo);
    ref.read(sesionProvider.notifier).iniciarSesion(perfil);
    await ref
        .read(credencialesStorageProvider)
        .guardar(usuario: usuarioDemo.usuario, password: password);
  }

  Future<void> cerrarSesion() async {
    if (ref.read(usuarioActualDemoProvider) != null) {
      ref.read(usuarioActualDemoProvider.notifier).establecer(null);
      ref.read(sesionProvider.notifier).cerrarSesion();
      return;
    }
    await ref.read(supabaseClientProvider).auth.signOut();
    ref.read(sesionProvider.notifier).cerrarSesion();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AsyncValue<void>>(
  AuthController.new,
);
