import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Punto verde que pulsa en bucle — indica que una lista se actualiza sola
/// en tiempo real (ver bandeja_autorizaciones_page.dart), sin que el usuario
/// tenga que refrescar para confirmarlo.
class PuntoEnVivo extends StatefulWidget {
  const PuntoEnVivo({super.key, this.diametro = 8});

  final double diametro;

  @override
  State<PuntoEnVivo> createState() => _PuntoEnVivoState();
}

class _PuntoEnVivoState extends State<PuntoEnVivo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 0.35,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.diametro,
        height: widget.diametro,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
