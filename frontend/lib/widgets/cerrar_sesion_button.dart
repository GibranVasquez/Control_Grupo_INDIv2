import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth_controller.dart';

/// Botón de "Cerrar sesión" reutilizable entre los 3 roles (chofer,
/// administrativo, finanzas): pide confirmación y luego invoca
/// `authControllerProvider.notifier.cerrarSesion()`, que limpia sesión, JWT,
/// credenciales de biometría y los datos sincronizados de PowerSync — el
/// router regresa solo a /login apenas `sesionProvider` queda en null (ver
/// app_router.dart).
class CerrarSesionButton extends ConsumerWidget {
  const CerrarSesionButton({super.key, this.color, this.conEtiqueta = false});

  /// Color del ícono/texto; si es nulo usa el color por defecto del tema.
  final Color? color;

  /// true: botón con ícono + texto "Cerrar sesión" (sidebar de escritorio).
  /// false: solo ícono con tooltip (encabezado del chofer).
  final bool conEtiqueta;

  Future<void> _confirmarYCerrar(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para continuar.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmar == true) {
      await ref.read(authControllerProvider.notifier).cerrarSesion();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (conEtiqueta) {
      return TextButton.icon(
        onPressed: () => _confirmarYCerrar(context, ref),
        icon: Icon(Icons.logout_rounded, size: 18, color: color),
        label: Text('Cerrar sesión', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.centerLeft,
        ),
      );
    }
    return IconButton(
      onPressed: () => _confirmarYCerrar(context, ref),
      icon: Icon(Icons.logout_rounded, color: color),
      tooltip: 'Cerrar sesión',
    );
  }
}
