import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'session_provider.dart';

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> iniciarSesion({
    required String numeroEmpleado,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final perfil = await ref
          .read(perfilRepositoryProvider)
          .iniciarSesion(numeroEmpleado: numeroEmpleado, password: password);
      // El JWT ya quedó guardado en TokenStorage dentro de iniciarSesion() de
      // ApiPerfilRepository; PowerSync reutiliza ese mismo token al conectar
      // (ver services/powersync/powersync_client.dart), sin login aparte.
      //
      // conectar() va ANTES de sesionProvider.iniciarSesion(): setear la
      // sesión dispara el redirect del router de inmediato (_SesionListenable
      // en app_router.dart escucha sesionProvider de forma síncrona), lo que
      // monta la pantalla del rol (ej. ChoferHomePage) y esta ya consulta el
      // catálogo local de PowerSync (vehiculoPorIdProvider). Si la sesión se
      // marca antes de que termine la primera sincronización, esa consulta
      // corre contra un catálogo local todavía vacío y truena con "no
      // encontrado en el catálogo local" — pasa siempre en un dispositivo
      // nuevo o recién deslogueado, no solo cuando la red va lenta.
      await ref.read(powerSyncClientProvider).conectar();
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

  Future<void> cerrarSesion() async {
    // Limpia también las credenciales guardadas para "Ingresar con Huella/Face
    // ID" (ver CredencialesStorage/iniciarSesionConBiometria): de lo contrario
    // un dispositivo compartido podría reabrir la sesión de este usuario con
    // solo la biometría de quien lo use después, aunque haya "cerrado sesión".
    //
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
