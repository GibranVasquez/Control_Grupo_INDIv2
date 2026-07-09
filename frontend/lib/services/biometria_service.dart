import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Envuelve `local_auth` y excluye por completo Windows/web/desktop: ahí `soportadaEnPlataforma`
/// es false y ningún método de este servicio llega a tocar el plugin nativo.
class BiometriaService {
  final _auth = LocalAuthentication();

  bool get soportadaEnPlataforma =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> disponible() async {
    if (!soportadaEnPlataforma) return false;
    try {
      final dispositivoSoportado = await _auth.isDeviceSupported();
      final puedeChecarBiometricos = await _auth.canCheckBiometrics;
      return dispositivoSoportado && puedeChecarBiometricos;
    } on Exception {
      return false;
    }
  }

  Future<bool> autenticar({String razon = 'Confirma tu identidad para ingresar'}) async {
    if (!soportadaEnPlataforma) return false;
    try {
      return await _auth.authenticate(
        localizedReason: razon,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on Exception {
      return false;
    }
  }
}
