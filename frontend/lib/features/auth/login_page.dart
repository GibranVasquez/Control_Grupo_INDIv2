import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_typography.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _numeroEmpleadoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _verPassword = false;

  @override
  void dispose() {
    _numeroEmpleadoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final numeroEmpleado = _numeroEmpleadoCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (numeroEmpleado.isEmpty || password.isEmpty) return;

    await ref.read(authControllerProvider.notifier).iniciarSesion(
          numeroEmpleado: numeroEmpleado,
          password: password,
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
              content: const Text('No pudimos iniciar sesión. Revisa tus datos e intenta de nuevo.'),
            ),
          );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                            label: 'NÚMERO DE EMPLEADO',
                            controller: _numeroEmpleadoCtrl,
                            hint: 'INDI-04871',
                            mono: true,
                          ),
                          const SizedBox(height: 16),
                          _CampoPassword(
                            controller: _passwordCtrl,
                            verPassword: _verPassword,
                            onToggleVer: () => setState(() => _verPassword = !_verPassword),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: cargando ? null : () {},
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
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
                          _BotonIngresar(cargando: cargando, onPressed: _entrar),
                          const SizedBox(height: 22),
                          _DivisorConTexto(texto: 'o'),
                          const SizedBox(height: 22),
                          _BotonSso(habilitado: !cargando),
                          const SizedBox(height: 22),
                          const Center(
                            child: Text(
                              'Grupo INDI © 2026 · v1.0',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5),
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
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      ),
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
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
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
          child: Text(texto, style: const TextStyle(color: AppColors.textTertiary)),
        ),
        const Expanded(child: Divider(color: AppColors.borderInput)),
      ],
    );
  }
}

class _BotonSso extends StatelessWidget {
  const _BotonSso({required this.habilitado});

  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: habilitado ? () {} : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/images/indi_logo.jpg', width: 22, height: 22),
          ),
          const SizedBox(width: 10),
          const Text(
            'Acceso corporativo INDI',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
            ),
          ),
        ],
      ),
    );
  }
}
