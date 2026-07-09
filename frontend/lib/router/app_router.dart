import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/administrativo/administrativo_home_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
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
  static const registro = '/registro';
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
        path: AppRoutes.registro,
        builder: (context, state) => const RegisterPage(),
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
        builder: (context, state) =>
            RespuestaAutorizacionPage(solicitud: state.extra as SolicitudAutorizacion),
      ),
      GoRoute(
        path: AppRoutes.comprobarCarga,
        builder: (context, state) =>
            ComprobarCargaPage(solicitud: state.extra as SolicitudAutorizacion),
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
  final enAuthPublica = enLogin || ruta == AppRoutes.registro;

  if (perfil == null) {
    return enAuthPublica ? null : AppRoutes.login;
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
