import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/enums.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_typography.dart';

/// Tipo de unidad para el formulario de registro. Es más granular que
/// [TipoUnidad] del backend (que solo distingue vehiculo/maquinaria):
/// aquí "pipa" también es TipoUnidad.vehiculo en el modelo de datos, pero
/// visualmente necesita su propio set de campos (dónde carga combustible).
enum _TipoUnidadFormulario { vehiculo, pipa, maquinaria }

/// Pantalla de registro de chofer, previa al login (ver mockup del feature).
///
/// Por ahora es solo UI: valida todo localmente y no llama al backend, que
/// hoy solo permite alta de choferes desde administrativo/finanzas (ver
/// perfil.routes.ts). Cuando se defina el flujo real (solicitud pendiente de
/// aprobación vs. autoregistro directo) se cablea el envío aquí.
class RegistroChoferPage extends StatefulWidget {
  const RegistroChoferPage({super.key});

  @override
  State<RegistroChoferPage> createState() => _RegistroChoferPageState();
}

class _RegistroChoferPageState extends State<RegistroChoferPage> {
  final _formKey = GlobalKey<FormState>();

  final _nombresCtrl = TextEditingController();
  final _apellidoPaternoCtrl = TextEditingController();
  final _apellidoMaternoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _numeroEconomicoCtrl = TextEditingController();
  final _placasCtrl = TextEditingController();
  final _obraCtrl = TextEditingController();
  final _seReportaConCtrl = TextEditingController();
  final _dondeCargaCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarPasswordCtrl = TextEditingController();

  _TipoUnidadFormulario _tipoUnidad = _TipoUnidadFormulario.vehiculo;
  TipoCombustible _tipoCombustible = TipoCombustible.magna;
  bool _verPassword = false;
  bool _verConfirmar = false;
  bool _enviando = false;

  bool get _requierePlacas => _tipoUnidad == _TipoUnidadFormulario.vehiculo;
  bool get _requiereNumeroEconomico => !_requierePlacas;
  bool get _esPipa => _tipoUnidad == _TipoUnidadFormulario.pipa;

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidoPaternoCtrl.dispose();
    _apellidoMaternoCtrl.dispose();
    _edadCtrl.dispose();
    _correoCtrl.dispose();
    _numeroEconomicoCtrl.dispose();
    _placasCtrl.dispose();
    _obraCtrl.dispose();
    _seReportaConCtrl.dispose();
    _dondeCargaCtrl.dispose();
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarPasswordCtrl.dispose();
    super.dispose();
  }

  void _cambiarTipoUnidad(_TipoUnidadFormulario tipo) {
    if (tipo == _tipoUnidad) return;
    setState(() {
      _tipoUnidad = tipo;
      // Limpia el campo que ya no aplica para no arrastrar datos inválidos
      // de un tipo de unidad a otro (ej. placas guardadas al cambiar a pipa).
      if (_requierePlacas) {
        _numeroEconomicoCtrl.clear();
      } else {
        _placasCtrl.clear();
      }
      if (!_esPipa) _dondeCargaCtrl.clear();
    });
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    setState(() => _enviando = true);
    // Simulación: aún no hay endpoint público de autoregistro (ver
    // perfil.routes.ts, alta restringida a administrativo/finanzas).
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _enviando = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            '¡Registro recibido, ${_nombresCtrl.text.trim()}! '
            'Un administrador validará tu cuenta antes de que puedas ingresar.',
          ),
        ),
      );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.cardLarge),
                  boxShadow: AppShadows.mobileCard,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Encabezado(onCancelar: () => context.go('/login')),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _TituloSeccion('DATOS PERSONALES'),
                            const SizedBox(height: 14),
                            _Campo(
                              label: 'NOMBRE(S)',
                              controller: _nombresCtrl,
                              hint: 'Antonio',
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => _validarTexto(v, minimo: 2),
                            ),
                            const SizedBox(height: 16),
                            _FilaDosCampos(
                              izquierda: _Campo(
                                label: 'APELLIDO PATERNO',
                                controller: _apellidoPaternoCtrl,
                                hint: 'Ponce',
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => _validarTexto(v, minimo: 2),
                              ),
                              derecha: _Campo(
                                label: 'APELLIDO MATERNO',
                                controller: _apellidoMaternoCtrl,
                                hint: 'Ruiz',
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => _validarTexto(v, minimo: 2),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FilaDosCampos(
                              izquierda: _Campo(
                                label: 'EDAD',
                                controller: _edadCtrl,
                                hint: '32',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                validator: _validarEdad,
                              ),
                              derecha: _Campo(
                                label: 'CORREO ELECTRÓNICO',
                                controller: _correoCtrl,
                                hint: 'antonio@correo.com',
                                keyboardType: TextInputType.emailAddress,
                                validator: _validarCorreo,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _TituloSeccion('UNIDAD QUE MANEJA'),
                            const SizedBox(height: 14),
                            _SelectorTipoUnidad(
                              seleccionado: _tipoUnidad,
                              onChanged: _cambiarTipoUnidad,
                            ),
                            const SizedBox(height: 16),
                            _FilaDosCampos(
                              izquierda: _SelectorCombustible(
                                seleccionado: _tipoCombustible,
                                onChanged: (t) =>
                                    setState(() => _tipoCombustible = t),
                              ),
                              derecha: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _requiereNumeroEconomico
                                    ? _Campo(
                                        key: const ValueKey('economico'),
                                        label: 'N° ECONÓMICO',
                                        controller: _numeroEconomicoCtrl,
                                        hint: 'PIP-07',
                                        mono: true,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        validator: (v) =>
                                            _validarTexto(v, minimo: 1),
                                      )
                                    : _Campo(
                                        key: const ValueKey('placas'),
                                        label: 'N° DE PLACAS',
                                        controller: _placasCtrl,
                                        hint: 'XA-482-19',
                                        mono: true,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        validator: (v) =>
                                            _validarTexto(v, minimo: 5),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _TituloSeccion('OBRA Y SUPERVISIÓN'),
                            const SizedBox(height: 14),
                            _FilaDosCampos(
                              izquierda: _Campo(
                                label: 'OBRA / FRENTE',
                                controller: _obraCtrl,
                                hint: 'Libramiento Sur',
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => _validarTexto(v, minimo: 2),
                              ),
                              derecha: _Campo(
                                label: 'SE REPORTA CON',
                                controller: _seReportaConCtrl,
                                hint: 'Ing. U. Martínez',
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => _validarTexto(v, minimo: 2),
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: _esPipa
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: _AvisoPipa(
                                        controller: _dondeCargaCtrl,
                                        validator: _esPipa
                                            ? (v) =>
                                                _validarTexto(v, minimo: 3)
                                            : null,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 24),
                            const _TituloSeccion('ACCESO A LA APP'),
                            const SizedBox(height: 14),
                            _Campo(
                              label: 'USUARIO',
                              controller: _usuarioCtrl,
                              hint: 'INDI-04871',
                              mono: true,
                              validator: (v) => _validarTexto(v, minimo: 3),
                            ),
                            const SizedBox(height: 16),
                            _CampoPassword(
                              label: 'CONTRASEÑA',
                              controller: _passwordCtrl,
                              verPassword: _verPassword,
                              onToggleVer: () =>
                                  setState(() => _verPassword = !_verPassword),
                              validator: _validarPassword,
                            ),
                            const SizedBox(height: 16),
                            _CampoPassword(
                              label: 'CONFIRMAR CONTRASEÑA',
                              controller: _confirmarPasswordCtrl,
                              verPassword: _verConfirmar,
                              onToggleVer: () => setState(
                                () => _verConfirmar = !_verConfirmar,
                              ),
                              validator: _validarConfirmarPassword,
                            ),
                            const SizedBox(height: 26),
                            _BotonGuardar(
                              cargando: _enviando,
                              onPressed: _enviar,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed:
                                  _enviando ? null : () => context.go('/login'),
                              child: const Text(
                                'Ya tengo una cuenta · Ingresar',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validarTexto(String? v, {required int minimo}) {
    final valor = v?.trim() ?? '';
    if (valor.isEmpty) return 'Requerido';
    if (valor.length < minimo) return 'Muy corto';
    return null;
  }

  String? _validarEdad(String? v) {
    final valor = v?.trim() ?? '';
    if (valor.isEmpty) return 'Requerido';
    final edad = int.tryParse(valor);
    if (edad == null || edad < 18 || edad > 75) return 'Edad inválida';
    return null;
  }

  String? _validarCorreo(String? v) {
    final valor = v?.trim() ?? '';
    if (valor.isEmpty) return 'Requerido';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(valor)) return 'Correo inválido';
    return null;
  }

  String? _validarPassword(String? v) {
    final valor = v ?? '';
    if (valor.isEmpty) return 'Requerido';
    if (valor.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  String? _validarConfirmarPassword(String? v) {
    final valor = v ?? '';
    if (valor.isEmpty) return 'Requerido';
    if (valor != _passwordCtrl.text) return 'No coincide';
    return null;
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.onCancelar});

  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 26),
      decoration: const BoxDecoration(gradient: AppGradients.brand),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Registrar chofer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadii.badge),
                      ),
                      child: const Text(
                        'Solo choferes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Completa tus datos para solicitar tu acceso',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancelar,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _FilaDosCampos extends StatelessWidget {
  const _FilaDosCampos({required this.izquierda, required this.derecha});

  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: izquierda),
        const SizedBox(width: 14),
        Expanded(child: derecha),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.mono = false,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool mono;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: mono
              ? AppTypography.mono(fontSize: 17, color: AppColors.navy)
              : const TextStyle(fontSize: 16, color: AppColors.navy),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textPlaceholder),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class _CampoPassword extends StatelessWidget {
  const _CampoPassword({
    required this.label,
    required this.controller,
    required this.verPassword,
    required this.onToggleVer,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final bool verPassword;
  final VoidCallback onToggleVer;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return _Campo(
      label: label,
      controller: controller,
      obscureText: !verPassword,
      validator: validator,
      suffix: TextButton(
        onPressed: onToggleVer,
        child: Text(
          verPassword ? 'Ocultar' : 'Ver',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SelectorTipoUnidad extends StatelessWidget {
  const _SelectorTipoUnidad({required this.seleccionado, required this.onChanged});

  final _TipoUnidadFormulario seleccionado;
  final ValueChanged<_TipoUnidadFormulario> onChanged;

  static const _opciones = [
    (_TipoUnidadFormulario.vehiculo, '🚗', 'Vehículo'),
    (_TipoUnidadFormulario.pipa, '🛢️', 'Pipa'),
    (_TipoUnidadFormulario.maquinaria, '🚜', 'Maquinaria'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TIPO DE UNIDAD QUE MANEJA',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _opciones.map((opcion) {
            final (tipo, emoji, etiqueta) = opcion;
            final activo = tipo == seleccionado;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: tipo == _opciones.last.$1 ? 0 : 8,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  onTap: () => onChanged(tipo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: activo ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.input),
                      border: Border.all(
                        color: activo ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                      boxShadow: activo ? AppShadows.primaryButton : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(
                          etiqueta,
                          style: TextStyle(
                            color: activo
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SelectorCombustible extends StatelessWidget {
  const _SelectorCombustible({required this.seleccionado, required this.onChanged});

  final TipoCombustible seleccionado;
  final ValueChanged<TipoCombustible> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TIPO DE COMBUSTIBLE',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TipoCombustible>(
          initialValue: seleccionado,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: TipoCombustible.values
              .map(
                (t) => DropdownMenuItem(value: t, child: Text(t.etiqueta)),
              )
              .toList(),
          style: const TextStyle(fontSize: 16, color: AppColors.navy),
        ),
      ],
    );
  }
}

class _AvisoPipa extends StatelessWidget {
  const _AvisoPipa({required this.controller, required this.validator});

  final TextEditingController controller;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppRadii.miniCard),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SOLO PIPA · ¿DÓNDE CARGA EL COMBUSTIBLE?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Estación Pemex Carretera 190',
              hintStyle: TextStyle(color: AppColors.textPlaceholder),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonGuardar extends StatelessWidget {
  const _BotonGuardar({required this.cargando, required this.onPressed});

  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card - 1),
        boxShadow: AppShadows.primaryButton,
      ),
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        child: cargando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text('Guardar chofer'),
      ),
    );
  }
}
