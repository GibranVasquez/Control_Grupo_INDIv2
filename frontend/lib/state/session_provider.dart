import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

class SesionNotifier extends Notifier<Perfil?> {
  @override
  Perfil? build() => null;

  void iniciarSesion(Perfil perfil) => state = perfil;

  void cerrarSesion() => state = null;
}

/// null mientras no hay sesión iniciada.
final sesionProvider = NotifierProvider<SesionNotifier, Perfil?>(SesionNotifier.new);
