import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/administrativo/administrativo_home_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/registro_chofer_page.dart';
import '../features/chofer/chofer_home_page.dart';
import '../features/chofer/comprobar_carga_page.dart';
import '../features/chofer/respuesta_autorizacion_page.dart';
import '../features/chofer/solicitar_litros_page.dart';
import '../features/finanzas/finanzas_home_page.dart';
import '../models/models.dart';
import '../state/session_provider.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const registroChofer = '/registro-chofer';
  static const chofer = '/chofer';
  static const solicitarLitros = '/chofer/solicitar';
  static const respuestaAutorizacion = '/chofer/respuesta';
  static const comprobarCarga = '/chofer/comprobar';
  static const administrativo = '/administrativo';
  static const finanzas = '/finanzas';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: _SesionListenable(ref),
    redirect: (context, state) => _redirigirSegunSesion(ref, state),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.registroChofer,
        builder: (context, state) => const RegistroChoferPage(),
      ),
      GoRoute(
        path: AppRoutes.chofer,
        builder: (context, state) => const ChoferHomePage(),
      ),
      GoRoute(
        path: AppRoutes.solicitarLitros,
        builder: (context, state) => const SolicitarLitrosPage(),
      ),
      GoRoute(
        path: AppRoutes.respuestaAutorizacion,
        builder: (context, state) {
          final solicitud = state.extra;
          if (solicitud is! SolicitudAutorizacion) return const _RutaInvalida();
          return RespuestaAutorizacionPage(solicitud: solicitud);
        },
      ),
      GoRoute(
        path: AppRoutes.comprobarCarga,
        builder: (context, state) {
          final solicitud = state.extra;
          if (solicitud is! SolicitudAutorizacion) return const _RutaInvalida();
          return ComprobarCargaPage(solicitud: solicitud);
        },
      ),
      GoRoute(
        path: AppRoutes.administrativo,
        builder: (context, state) => const AdministrativoHomePage(),
      ),
      GoRoute(
        path: AppRoutes.finanzas,
        builder: (context, state) => const FinanzasHomePage(),
      ),
    ],
  );
});

String? _redirigirSegunSesion(Ref ref, GoRouterState state) {
  final perfil = ref.read(sesionProvider);
  final ruta = state.matchedLocation;
  final enLogin = ruta == AppRoutes.login;
  final enRegistro = ruta == AppRoutes.registroChofer;

  if (perfil == null) {
    return (enLogin || enRegistro) ? null : AppRoutes.login;
  }

  final rutaDeSuRol = _rutaHomePorRol(perfil.rol);
  final dentroDeSuRol = ruta.startsWith(rutaDeSuRol);

  if (enLogin || !dentroDeSuRol) {
    return rutaDeSuRol;
  }
  return null;
}

String _rutaHomePorRol(RolUsuario rol) => switch (rol) {
      RolUsuario.chofer => AppRoutes.chofer,
      RolUsuario.administrativo => AppRoutes.administrativo,
      RolUsuario.finanzas => AppRoutes.finanzas,
    };

/// Puente para que go_router escuche cambios de sesión sin acoplarse a Riverpod directamente.
class _SesionListenable extends ChangeNotifier {
  _SesionListenable(this._ref) {
    _ref.listen(sesionProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

/// Pantalla de aterrizaje segura cuando `state.extra` no trae el tipo
/// esperado (ej. deep link directo a /chofer/comprobar sin pasar por la
/// pantalla anterior, o un hot-reload que perdió el objeto en memoria):
/// en vez de que el `as SolicitudAutorizacion` truene con un crash, redirige
/// al home del chofer apenas se monta el primer frame.
class _RutaInvalida extends ConsumerWidget {
  const _RutaInvalida();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(AppRoutes.chofer);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
