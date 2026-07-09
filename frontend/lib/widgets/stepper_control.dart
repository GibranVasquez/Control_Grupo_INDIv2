import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Control −/+ usado para litros y kilómetros. En móvil se ve grande (60×60, número 44px);
/// en las pantallas de comprobación de carga el handoff lo usa más compacto (40×40).
/// El número también es editable: un tap abre un campo de texto para escribir el valor.
class StepperControl extends StatefulWidget {
  const StepperControl({
    super.key,
    required this.valor,
    required this.min,
    required this.max,
    required this.paso,
    required this.onChanged,
    this.sufijo,
    this.grande = true,
  });

  final num valor;
  final num min;
  final num max;
  final num paso;
  final ValueChanged<num> onChanged;
  final String? sufijo;
  final bool grande;

  @override
  State<StepperControl> createState() => _StepperControlState();
}

class _StepperControlState extends State<StepperControl> {
  bool _editando = false;
  late final TextEditingController _ctrl = TextEditingController();
  late final FocusNode _focusNode = FocusNode()..addListener(_alPerderFoco);

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _alPerderFoco() {
    if (!_focusNode.hasFocus && _editando) _confirmarEdicion();
  }

  void _ajustar(num delta) {
    final nuevo = (widget.valor + delta).clamp(widget.min, widget.max);
    if (nuevo != widget.valor) widget.onChanged(nuevo);
  }

  void _iniciarEdicion() {
    _ctrl.text = widget.valor.toStringAsFixed(0);
    setState(() => _editando = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    });
  }

  void _confirmarEdicion() {
    final parsed = num.tryParse(_ctrl.text.trim());
    if (parsed != null) {
      final nuevo = parsed.clamp(widget.min, widget.max);
      if (nuevo != widget.valor) widget.onChanged(nuevo);
    }
    setState(() => _editando = false);
  }

  @override
  Widget build(BuildContext context) {
    final botonLado = widget.grande ? 60.0 : 40.0;
    final numeroFontSize = widget.grande ? 44.0 : 30.0;
    final glifoSize = widget.grande ? 30.0 : 20.0;
    final ancho = widget.grande ? 140.0 : 90.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BotonPasoRedondo(
          lado: botonLado,
          glifoSize: glifoSize,
          icono: Icons.remove,
          habilitado: widget.valor > widget.min,
          onTap: () => _ajustar(-widget.paso),
        ),
        SizedBox(
          width: ancho,
          child: _editando
              ? TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _confirmarEdicion(),
                  style: AppTypography.mono(
                    fontSize: numeroFontSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                  ),
                )
              : GestureDetector(
                  onTap: _iniciarEdicion,
                  child: Text(
                    widget.sufijo == null ? '${widget.valor}' : '${widget.valor} ${widget.sufijo}',
                    textAlign: TextAlign.center,
                    style: AppTypography.mono(
                      fontSize: numeroFontSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
        ),
        _BotonPasoRedondo(
          lado: botonLado,
          glifoSize: glifoSize,
          icono: Icons.add,
          habilitado: widget.valor < widget.max,
          onTap: () => _ajustar(widget.paso),
        ),
      ],
    );
  }
}

class _BotonPasoRedondo extends StatelessWidget {
  const _BotonPasoRedondo({
    required this.lado,
    required this.glifoSize,
    required this.icono,
    required this.habilitado,
    required this.onTap,
  });

  final double lado;
  final double glifoSize;
  final IconData icono;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(lado / 2),
      onTap: habilitado ? onTap : null,
      child: Container(
        width: lado,
        height: lado,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: habilitado ? AppColors.infoBg : AppColors.surfaceLight,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icono,
          size: glifoSize,
          color: habilitado ? AppColors.primary : AppColors.textTertiary,
        ),
      ),
    );
  }
}
