import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dev/datos_demo.dart';
import '../dev/usuario_registrado.dart';

/// CRUD en memoria de altas de usuario (ver [DatosDemo.usuariosRegistrados]).
/// Notifier en vez de Provider simple porque necesita exponer una operación de escritura (`registrar`).
class UsuariosRegistradosNotifier extends Notifier<List<UsuarioRegistrado>> {
  @override
  List<UsuarioRegistrado> build() => List.unmodifiable(DatosDemo.usuariosRegistrados);

  /// Lanza [ArgumentError] si el usuario ya existe, para que la pantalla de registro lo muestre.
  void registrar(UsuarioRegistrado usuario) {
    final yaExiste = DatosDemo.usuariosRegistrados
        .any((u) => u.usuario.toLowerCase() == usuario.usuario.toLowerCase());
    if (yaExiste) {
      throw ArgumentError('Ya existe una cuenta con el usuario "${usuario.usuario}".');
    }
    DatosDemo.usuariosRegistrados.add(usuario);
    state = List.unmodifiable(DatosDemo.usuariosRegistrados);
  }

  UsuarioRegistrado? buscarPorCredenciales(String usuario, String password) {
    for (final u in state) {
      if (u.usuario.toLowerCase() == usuario.toLowerCase() && u.password == password) {
        return u;
      }
    }
    return null;
  }
}

final usuariosRegistradosProvider =
    NotifierProvider<UsuariosRegistradosNotifier, List<UsuarioRegistrado>>(
  UsuariosRegistradosNotifier.new,
);

/// Usuario demo con el que se inició sesión (si el login fue por match local y no por Supabase).
/// Lo consumen pantallas como `solicitar_litros_page.dart` para precargar vehículo/obra/ingeniero.
class UsuarioActualDemoNotifier extends Notifier<UsuarioRegistrado?> {
  @override
  UsuarioRegistrado? build() => null;

  void establecer(UsuarioRegistrado? usuario) => state = usuario;
}

final usuarioActualDemoProvider =
    NotifierProvider<UsuarioActualDemoNotifier, UsuarioRegistrado?>(
  UsuarioActualDemoNotifier.new,
);
