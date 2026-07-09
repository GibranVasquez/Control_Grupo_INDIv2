import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/usuario_registrado.dart';
import '../../models/models.dart';
import '../../state/catalogos_provider.dart';
import '../../state/usuarios_registrados_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  int _paso = 0;

  final _formDatosPersonales = GlobalKey<FormState>();
  final _formDatosLaborales = GlobalKey<FormState>();
  final _formDatosVehiculo = GlobalKey<FormState>();

  final _nombresCtrl = TextEditingController();
  final _apellidoPaternoCtrl = TextEditingController();
  final _apellidoMaternoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? _obraId;
  String? _ingenieroId;
  final _lugarCargaCtrl = TextEditingController();

  TipoVehiculoDemo _tipoVehiculo = TipoVehiculoDemo.camioneta;
  TipoCombustible _tipoCombustible = TipoCombustible.magna;
  final _identificadorCtrl = TextEditingController();

  bool _enviando = false;

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidoPaternoCtrl.dispose();
    _apellidoMaternoCtrl.dispose();
    _edadCtrl.dispose();
    _telefonoCtrl.dispose();
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    _lugarCargaCtrl.dispose();
    _identificadorCtrl.dispose();
    super.dispose();
  }

  void _onTipoVehiculoChanged(TipoVehiculoDemo tipo) {
    setState(() {
      _tipoVehiculo = tipo;
      _tipoCombustible = tipo.combustiblePredeterminado;
      _identificadorCtrl.clear();
    });
  }

  bool _validarPasoActual() {
    switch (_paso) {
      case 0:
        return _formDatosPersonales.currentState?.validate() ?? false;
      case 1:
        final formOk = _formDatosLaborales.currentState?.validate() ?? false;
        return formOk && _obraId != null && _ingenieroId != null;
      default:
        return _formDatosVehiculo.currentState?.validate() ?? false;
    }
  }

  void _siguiente() {
    if (!_validarPasoActual()) return;
    if (_paso < 2) {
      setState(() => _paso += 1);
    } else {
      _registrar();
    }
  }

  void _anterior() {
    if (_paso == 0) {
      context.pop();
      return;
    }
    setState(() => _paso -= 1);
  }

  Future<void> _registrar() async {
    setState(() => _enviando = true);
    try {
      final nuevoUsuario = UsuarioRegistrado(
        nombres: _nombresCtrl.text.trim(),
        apellidoPaterno: _apellidoPaternoCtrl.text.trim(),
        apellidoMaterno: _apellidoMaternoCtrl.text.trim(),
        edad: int.parse(_edadCtrl.text.trim()),
        telefono: _telefonoCtrl.text.trim(),
        usuario: _usuarioCtrl.text.trim(),
        password: _passwordCtrl.text,
        obraId: _obraId!,
        ingenieroId: _ingenieroId!,
        lugarCarga: _lugarCargaCtrl.text.trim(),
        tipoVehiculo: _tipoVehiculo,
        tipoCombustible: _tipoCombustible,
        identificadorVehiculo: _identificadorCtrl.text.trim(),
      );

      ref.read(usuariosRegistradosProvider.notifier).registrar(nuevoUsuario);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            'Cuenta creada. Ya puedes ingresar con el usuario "${nuevoUsuario.usuario}".',
          ),
        ),
      );
      context.pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e.message as String),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text(
          'Crear cuenta',
          style: TextStyle(color: AppColors.navy),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ResponsiveCenter(child: _IndicadorPasos(pasoActual: _paso)),
            Expanded(
              child: ResponsiveCenter(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: switch (_paso) {
                    0 => _PasoDatosPersonales(
                      formKey: _formDatosPersonales,
                      nombresCtrl: _nombresCtrl,
                      apellidoPaternoCtrl: _apellidoPaternoCtrl,
                      apellidoMaternoCtrl: _apellidoMaternoCtrl,
                      edadCtrl: _edadCtrl,
                      telefonoCtrl: _telefonoCtrl,
                      usuarioCtrl: _usuarioCtrl,
                      passwordCtrl: _passwordCtrl,
                    ),
                    1 => _PasoDatosLaborales(
                      formKey: _formDatosLaborales,
                      obraId: _obraId,
                      ingenieroId: _ingenieroId,
                      lugarCargaCtrl: _lugarCargaCtrl,
                      onObraChanged: (v) => setState(() => _obraId = v),
                      onIngenieroChanged: (v) =>
                          setState(() => _ingenieroId = v),
                    ),
                    _ => _PasoDatosVehiculo(
                      formKey: _formDatosVehiculo,
                      tipoVehiculo: _tipoVehiculo,
                      tipoCombustible: _tipoCombustible,
                      identificadorCtrl: _identificadorCtrl,
                      onTipoVehiculoChanged: _onTipoVehiculoChanged,
                      onCombustibleChanged: (v) =>
                          setState(() => _tipoCombustible = v),
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ResponsiveCenter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _enviando ? null : _anterior,
                    child: Text(_paso == 0 ? 'Cancelar' : 'Atrás'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.card - 1),
                      boxShadow: AppShadows.primaryButton,
                    ),
                    child: ElevatedButton(
                      onPressed: _enviando ? null : _siguiente,
                      child: _enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(_paso == 2 ? 'Crear cuenta' : 'Siguiente'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IndicadorPasos extends StatelessWidget {
  const _IndicadorPasos({required this.pasoActual});

  final int pasoActual;

  static const _titulos = ['Datos personales', 'Datos laborales', 'Vehículo'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: List.generate(_titulos.length, (i) {
          final activo = i == pasoActual;
          final completado = i < pasoActual;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Divider(
                          color: completado || activo
                              ? AppColors.primary
                              : AppColors.border,
                          thickness: 2,
                        ),
                      ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: activo || completado
                          ? AppColors.primary
                          : AppColors.surface,
                      child: completado
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: activo
                                    ? Colors.white
                                    : AppColors.textTertiary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    if (i < _titulos.length - 1)
                      Expanded(
                        child: Divider(
                          color: completado
                              ? AppColors.primary
                              : AppColors.border,
                          thickness: 2,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _titulos[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: activo ? AppColors.navy : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _PasoDatosPersonales extends StatelessWidget {
  const _PasoDatosPersonales({
    required this.formKey,
    required this.nombresCtrl,
    required this.apellidoPaternoCtrl,
    required this.apellidoMaternoCtrl,
    required this.edadCtrl,
    required this.telefonoCtrl,
    required this.usuarioCtrl,
    required this.passwordCtrl,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nombresCtrl;
  final TextEditingController apellidoPaternoCtrl;
  final TextEditingController apellidoMaternoCtrl;
  final TextEditingController edadCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController usuarioCtrl;
  final TextEditingController passwordCtrl;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Etiqueta('DATOS PERSONALES'),
          const SizedBox(height: 12),
          _CampoTexto(label: 'Nombre(s)', controller: nombresCtrl),
          const SizedBox(height: 14),
          _CampoTexto(
            label: 'Apellido paterno',
            controller: apellidoPaternoCtrl,
          ),
          const SizedBox(height: 14),
          _CampoTexto(
            label: 'Apellido materno',
            controller: apellidoMaternoCtrl,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CampoTexto(
                  label: 'Edad',
                  controller: edadCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null) return 'Ingresa un número';
                    if (n < 18 || n > 70) return 'Debe ser 18-70';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _CampoTexto(
                  label: 'Teléfono',
                  controller: telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final digits = v?.trim() ?? '';
                    if (digits.length != 10) return '10 dígitos';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _Etiqueta('CREDENCIALES DE ACCESO'),
          const SizedBox(height: 12),
          _CampoTexto(
            label: 'Usuario',
            controller: usuarioCtrl,
            hint: 'INDI-04871',
            mono: true,
          ),
          const SizedBox(height: 14),
          _CampoTexto(
            label: 'Contraseña',
            controller: passwordCtrl,
            obscureText: true,
            validator: (v) =>
                (v?.length ?? 0) < 6 ? 'Mínimo 6 caracteres' : null,
          ),
        ],
      ),
    );
  }
}

class _PasoDatosLaborales extends ConsumerWidget {
  const _PasoDatosLaborales({
    required this.formKey,
    required this.obraId,
    required this.ingenieroId,
    required this.lugarCargaCtrl,
    required this.onObraChanged,
    required this.onIngenieroChanged,
  });

  final GlobalKey<FormState> formKey;
  final String? obraId;
  final String? ingenieroId;
  final TextEditingController lugarCargaCtrl;
  final ValueChanged<String?> onObraChanged;
  final ValueChanged<String?> onIngenieroChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Catálogos cache-first (SharedPreferences): la primera vez se resuelven del "backend"
    // (hoy DatosDemo; mañana Supabase) y quedan en disco, así que la siguiente apertura de
    // register_page.dart no depende de red para mostrar estas dos listas.
    final obrasAsync = ref.watch(obrasCatalogoProvider);
    final ingenierosAsync = ref.watch(ingenierosCatalogoProvider);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Etiqueta('DATOS LABORALES'),
          const SizedBox(height: 12),
          _CampoLabel(label: 'Obra en la que trabaja'),
          const SizedBox(height: 8),
          obrasAsync.when(
            data: (obras) => DropdownButtonFormField<String>(
              initialValue: obraId,
              items: obras
                  .map(
                    (o) => DropdownMenuItem(value: o.id, child: Text(o.nombre)),
                  )
                  .toList(),
              onChanged: onObraChanged,
              validator: (v) => v == null ? 'Selecciona una obra' : null,
              decoration: const InputDecoration(
                hintText: 'Selecciona una obra',
              ),
            ),
            loading: () => const _SkeletonCampo(),
            error: (e, st) =>
                Text('No se pudo cargar el catálogo de obras: $e'),
          ),
          const SizedBox(height: 14),
          _CampoLabel(label: 'Ingeniero con el que se reporta'),
          const SizedBox(height: 8),
          ingenierosAsync.when(
            data: (ingenieros) => DropdownButtonFormField<String>(
              initialValue: ingenieroId,
              items: ingenieros
                  .map(
                    (i) => DropdownMenuItem(
                      value: i.id,
                      child: Text(i.nombreCompleto),
                    ),
                  )
                  .toList(),
              onChanged: onIngenieroChanged,
              validator: (v) => v == null ? 'Selecciona un ingeniero' : null,
              decoration: const InputDecoration(
                hintText: 'Selecciona un ingeniero',
              ),
            ),
            loading: () => const _SkeletonCampo(),
            error: (e, st) =>
                Text('No se pudo cargar el catálogo de ingenieros: $e'),
          ),
          const SizedBox(height: 14),
          _CampoTexto(
            label: 'Lugar donde carga combustible normalmente',
            controller: lugarCargaCtrl,
            hint: 'Ej. Almacén / Patio de obra km 360',
          ),
        ],
      ),
    );
  }
}

class _PasoDatosVehiculo extends StatelessWidget {
  const _PasoDatosVehiculo({
    required this.formKey,
    required this.tipoVehiculo,
    required this.tipoCombustible,
    required this.identificadorCtrl,
    required this.onTipoVehiculoChanged,
    required this.onCombustibleChanged,
  });

  final GlobalKey<FormState> formKey;
  final TipoVehiculoDemo tipoVehiculo;
  final TipoCombustible tipoCombustible;
  final TextEditingController identificadorCtrl;
  final ValueChanged<TipoVehiculoDemo> onTipoVehiculoChanged;
  final ValueChanged<TipoCombustible> onCombustibleChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Etiqueta('TIPO DE VEHÍCULO'),
          const SizedBox(height: 12),
          Row(
            children: TipoVehiculoDemo.values.map((tipo) {
              final activo = tipo == tipoVehiculo;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: tipo == TipoVehiculoDemo.values.last ? 0 : 8,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    onTap: () => onTipoVehiculoChanged(tipo),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: activo ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.input),
                        border: Border.all(
                          color: activo ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        tipo.etiqueta,
                        style: TextStyle(
                          color: activo
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const _Etiqueta('COMBUSTIBLE'),
          const SizedBox(height: 12),
          if (tipoVehiculo.permiteElegirCombustible)
            FuelTypeChipSelector(
              seleccionado: tipoCombustible,
              onChanged: onCombustibleChanged,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tipoVehiculo.etiqueta} usa ${tipoCombustible.etiqueta} de forma predeterminada.',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          _Etiqueta(tipoVehiculo.etiquetaIdentificador.toUpperCase()),
          const SizedBox(height: 12),
          _CampoTexto(
            label: tipoVehiculo.etiquetaIdentificador,
            controller: identificadorCtrl,
            hint: tipoVehiculo.hintIdentificador,
            mono: true,
          ),
        ],
      ),
    );
  }
}

/// Placeholder mientras `obrasCatalogoProvider`/`ingenierosCatalogoProvider` resuelven
/// (solo se ve en el primer arranque de la app o si expiró la caché de 12h).
class _SkeletonCampo extends StatelessWidget {
  const _SkeletonCampo();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.borderInput, width: 1.5),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _CampoLabel extends StatelessWidget {
  const _CampoLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
      ),
    );
  }
}

class _CampoTexto extends StatelessWidget {
  const _CampoTexto({
    required this.label,
    required this.controller,
    this.hint,
    this.mono = false,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool mono;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CampoLabel(label: label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: mono
              ? AppTypography.mono(fontSize: 16, color: AppColors.navy)
              : null,
          decoration: InputDecoration(hintText: hint),
          validator:
              validator ??
              (v) => (v?.trim().isEmpty ?? true) ? 'Campo requerido' : null,
        ),
      ],
    );
  }
}
