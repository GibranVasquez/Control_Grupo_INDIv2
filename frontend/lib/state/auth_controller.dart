import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dev/usuario_registrado.dart';
import '../models/models.dart';
import 'providers.dart';
import 'session_provider.dart';
import 'usuarios_registrados_provider.dart';

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
      // Si hay match, entra sin tocar la API real; si no, se intenta el login real contra el backend.
      final usuarioDemo = ref
          .read(usuariosRegistradosProvider.notifier)
          .buscarPorCredenciales(numeroEmpleado, password);

      if (usuarioDemo != null) {
        await _entrarComoUsuarioDemo(usuarioDemo, password);
        return;
      }

      final perfil = await ref
          .read(perfilRepositoryProvider)
          .iniciarSesion(numeroEmpleado: numeroEmpleado, password: password);
      ref.read(usuarioActualDemoProvider.notifier).establecer(null);
      ref.read(sesionProvider.notifier).iniciarSesion(perfil);
      // El JWT ya quedó guardado en TokenStorage dentro de iniciarSesion() de
      // ApiPerfilRepository; PowerSync reutiliza ese mismo token al conectar
      // (ver services/powersync/powersync_client.dart), sin login aparte.
      await ref.read(powerSyncClientProvider).conectar();
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
    // Limpia también las credenciales guardadas para "Ingresar con Huella/Face
    // ID" (ver CredencialesStorage/iniciarSesionConBiometria): de lo contrario
    // un dispositivo compartido podría reabrir la sesión de este usuario con
    // solo la biometría de quien lo use después, aunque haya "cerrado sesión".
    if (ref.read(usuarioActualDemoProvider) != null) {
      ref.read(usuarioActualDemoProvider.notifier).establecer(null);
      ref.read(sesionProvider.notifier).cerrarSesion();
      await ref.read(credencialesStorageProvider).limpiar();
      ref.invalidate(puedeUsarBiometriaProvider);
      return;
    }
    // Corta el stream de PowerSync y borra los datos sincronizados del disco
    // antes de limpiar el JWT: no dejar solicitudes/cargas/catálogos de este
    // perfil en un dispositivo que otro usuario podría usar después.
    await ref.read(powerSyncClientProvider).desconectarYLimpiar();
    await ref.read(tokenStorageProvider).limpiar();
    await ref.read(credencialesStorageProvider).limpiar();
    ref.read(sesionProvider.notifier).cerrarSesion();
    ref.invalidate(puedeUsarBiometriaProvider);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AsyncValue<void>>(
  AuthController.new,
);
