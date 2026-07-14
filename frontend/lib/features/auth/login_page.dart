import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/auth_controller.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_typography.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _numeroEmpleadoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _verPassword = false;

  late final _entradaController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final _entradaFade = CurvedAnimation(
    parent: _entradaController,
    curve: Curves.easeOut,
  );
  late final _entradaDesplazamiento =
      Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
        CurvedAnimation(parent: _entradaController, curve: Curves.easeOutCubic),
      );

  @override
  void initState() {
    super.initState();
    _entradaController.forward();
  }

  @override
  void dispose() {
    _numeroEmpleadoCtrl.dispose();
    _passwordCtrl.dispose();
    _entradaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final numeroEmpleado = _numeroEmpleadoCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (numeroEmpleado.isEmpty || password.isEmpty) return;

    await ref
        .read(authControllerProvider.notifier)
        .iniciarSesion(numeroEmpleado: numeroEmpleado, password: password);
  }

  Future<void> _entrarConBiometria() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .iniciarSesionConBiometria();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos validar tu huella/Face ID. Ingresa con tu usuario y contraseña.',
          ),
        ),
      );
    }
  }

  void _mostrarProximamente() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Próximamente.')));
  }

  /// Acceso administrativo: antes entraba directo con una cuenta fija sin
  /// pedir nada, lo cual era un riesgo real (cualquiera con la app podía
  /// entrar como administrativo sin credenciales). Ahora solo abre un
  /// diálogo que pide usuario y contraseña como cualquier login;
  /// la única diferencia con "Ingresar" es la etiqueta/estilo, para dejar
  /// claro que es un acceso con privilegios.
  Future<void> _entrarComoAdministrador() async {
    final credenciales =
        await showDialog<({String numeroEmpleado, String password})>(
          context: context,
          builder: (_) => const _DialogoAccesoAdmin(),
        );
    if (credenciales == null || !mounted) return;

    await ref
        .read(authControllerProvider.notifier)
        .iniciarSesion(
          numeroEmpleado: credenciales.numeroEmpleado,
          password: credenciales.password,
        );
  }

  @override
  Widget build(BuildContext context) {
    final estadoLogin = ref.watch(authControllerProvider);
    final cargando = estadoLogin.isLoading;

    ref.listen(authControllerProvider, (previo, actual) {
      final error = actual.error;
      if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: const Text(
                'No pudimos iniciar sesión. Revisa tus datos e intenta de nuevo.',
              ),
            ),
          );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: FadeTransition(
              opacity: _entradaFade,
              child: SlideTransition(
                position: _entradaDesplazamiento,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.cardLarge),
                      boxShadow: AppShadows.mobileCard,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Encabezado(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Campo(
                                label: 'USUARIO',
                                controller: _numeroEmpleadoCtrl,
                                hint: 'antonio.ponce',
                                mono: true,
                              ),
                              const SizedBox(height: 16),
                              _CampoPassword(
                                controller: _passwordCtrl,
                                verPassword: _verPassword,
                                onToggleVer: () => setState(
                                  () => _verPassword = !_verPassword,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: cargando
                                      ? null
                                      : _mostrarProximamente,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _BotonIngresar(
                                cargando: cargando,
                                onPressed: _entrar,
                              ),
                              const SizedBox(height: 16),
                              _BotonBiometria(
                                cargando: cargando,
                                onPressed: _entrarConBiometria,
                              ),
                              // Atajo solo para desarrollo/pruebas: nunca debe
                              // llegar a un build de release ni a las tiendas —
                              // kDebugMode lo excluye por completo del binario
                              // compilado, no solo lo oculta visualmente.
                              if (kDebugMode) ...[
                                const SizedBox(height: 22),
                                _DivisorConTexto(texto: 'o'),
                                const SizedBox(height: 22),
                                _BotonAdmin(
                                  habilitado: !cargando,
                                  onPressed: _entrarComoAdministrador,
                                ),
                              ],
                              const SizedBox(height: 20),
                              _TarjetaRegistro(
                                habilitada: !cargando,
                                onTap: () => context.push('/registro-chofer'),
                              ),
                              const SizedBox(height: 18),
                              const Center(
                                child: Text(
                                  'Grupo INDI © 2026 · v1.0',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 40, 26, 34),
      decoration: const BoxDecoration(gradient: AppGradients.brand),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Image.asset(
              'assets/images/indi_logo.jpg',
              width: 66,
              height: 66,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'INDI Combustible',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Control de combustible en obra',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.label,
    required this.controller,
    this.hint,
    this.mono = false,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool mono;
  final bool obscureText;
  final Widget? suffix;

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
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: mono
              ? AppTypography.mono(fontSize: 19, color: AppColors.navy)
              : TextStyle(fontSize: 16, color: AppColors.navy),
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
    required this.controller,
    required this.verPassword,
    required this.onToggleVer,
  });

  final TextEditingController controller;
  final bool verPassword;
  final VoidCallback onToggleVer;

  @override
  Widget build(BuildContext context) {
    return _Campo(
      label: 'CONTRASEÑA',
      controller: controller,
      obscureText: !verPassword,
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

/// Solo se muestra en Android/iOS (nunca Windows/web) y solo si ya hay una sesión
/// previa guardada en este dispositivo: ver `puedeUsarBiometriaProvider`.
class _BotonBiometria extends ConsumerWidget {
  const _BotonBiometria({required this.cargando, required this.onPressed});

  final bool cargando;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puedeUsarBiometria = ref.watch(puedeUsarBiometriaProvider);

    return puedeUsarBiometria.when(
      data: (disponible) {
        if (!disponible) return const SizedBox.shrink();
        return Center(
          child: TextButton.icon(
            onPressed: cargando ? null : onPressed,
            icon: const Icon(Icons.fingerprint, color: AppColors.primary),
            label: const Text(
              'Ingresar con Huella/Face ID',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _BotonIngresar extends StatelessWidget {
  const _BotonIngresar({required this.cargando, required this.onPressed});

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
            : const Text('Ingresar'),
      ),
    );
  }
}

class _DivisorConTexto extends StatelessWidget {
  const _DivisorConTexto({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.borderInput)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            texto,
            style: const TextStyle(color: AppColors.textTertiary),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.borderInput)),
      ],
    );
  }
}

/// Diálogo que pide usuario y contraseña para el acceso administrativo —
/// reemplaza el atajo anterior que entraba sin pedir nada.
class _DialogoAccesoAdmin extends StatefulWidget {
  const _DialogoAccesoAdmin();

  @override
  State<_DialogoAccesoAdmin> createState() => _DialogoAccesoAdminState();
}

class _DialogoAccesoAdminState extends State<_DialogoAccesoAdmin> {
  final _numeroEmpleadoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _verPassword = false;

  @override
  void dispose() {
    _numeroEmpleadoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    final numeroEmpleado = _numeroEmpleadoCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (numeroEmpleado.isEmpty || password.isEmpty) return;
    Navigator.of(
      context,
    ).pop((numeroEmpleado: numeroEmpleado, password: password));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 380,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.cardLarge),
          boxShadow: AppShadows.mobileCard,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.secondary, AppColors.secondaryDark],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadii.badge),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Acceso de administrador',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Campo(
                    label: 'USUARIO',
                    controller: _numeroEmpleadoCtrl,
                    hint: 'usuario del administrador',
                    mono: true,
                  ),
                  const SizedBox(height: 16),
                  _CampoPassword(
                    controller: _passwordCtrl,
                    verPassword: _verPassword,
                    onToggleVer: () =>
                        setState(() => _verPassword = !_verPassword),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadii.card - 1,
                            ),
                            boxShadow: AppShadows.primaryButton,
                          ),
                          child: ElevatedButton(
                            onPressed: _confirmar,
                            child: const Text('Ingresar'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta con acento morado — se distingue del botón de "Ingresar" para
/// dejar claro que abre un acceso con privilegios, aunque el flujo (pedir
/// usuario y contraseña) sea el mismo.
class _BotonAdmin extends StatefulWidget {
  const _BotonAdmin({required this.habilitado, required this.onPressed});

  final bool habilitado;
  final VoidCallback onPressed;

  @override
  State<_BotonAdmin> createState() => _BotonAdminState();
}

class _BotonAdminState extends State<_BotonAdmin> {
  bool _presionado = false;

  void _setPresionado(bool valor) {
    if (!widget.habilitado) return;
    setState(() => _presionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPresionado(true),
      onTapCancel: () => _setPresionado(false),
      onTapUp: (_) => _setPresionado(false),
      child: AnimatedScale(
        scale: _presionado ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card - 1),
            onTap: widget.habilitado ? widget.onPressed : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card - 1),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.35),
                ),
                color: AppColors.secondaryBg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.secondary, AppColors.secondaryDark],
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Acceso de administrador',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondaryDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CTA interactiva para el registro de chofer: tarjeta completa (no un simple
/// link) con ícono, título/subtítulo y flecha que se desplaza al presionar —
/// busca que "Regístrate" se sienta como una acción de primer nivel, no una
/// nota al pie.
class _TarjetaRegistro extends StatefulWidget {
  const _TarjetaRegistro({required this.habilitada, required this.onTap});

  final bool habilitada;
  final VoidCallback onTap;

  @override
  State<_TarjetaRegistro> createState() => _TarjetaRegistroState();
}

class _TarjetaRegistroState extends State<_TarjetaRegistro> {
  bool _presionado = false;

  void _setPresionado(bool valor) {
    if (!widget.habilitada) return;
    setState(() => _presionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPresionado(true),
      onTapCancel: () => _setPresionado(false),
      onTapUp: (_) => _setPresionado(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card - 1),
          boxShadow: _presionado
              ? const []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    spreadRadius: -8,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card - 1),
            onTap: widget.habilitada ? widget.onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card - 1),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Color(0xFF0A3FB0)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¿Eres chofer y no tienes cuenta?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        Text(
                          'Regístrate en un minuto',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 160),
                    offset: _presionado ? const Offset(0.15, 0) : Offset.zero,
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
