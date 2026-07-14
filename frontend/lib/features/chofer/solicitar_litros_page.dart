import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../state/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_shadows.dart';
import '../../utils/errores_red.dart';
import '../../widgets/widgets.dart';

class SolicitarLitrosPage extends ConsumerStatefulWidget {
  const SolicitarLitrosPage({super.key});

  @override
  ConsumerState<SolicitarLitrosPage> createState() =>
      _SolicitarLitrosPageState();
}

class _SolicitarLitrosPageState extends ConsumerState<SolicitarLitrosPage> {
  TipoCombustible? _combustible;
  num? _litros;
  final _motivoCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  bool _excedeTope(int topeVehiculo) => (_litros ?? 0) > topeVehiculo;

  Future<void> _enviar(
    Perfil perfil,
    Vehiculo vehiculo,
    int topeVehiculo,
  ) async {
    if (_litros == null) return;
    if (_excedeTope(topeVehiculo) && _motivoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuéntanos por qué necesitas más litros del tope.'),
        ),
      );
      return;
    }
    final obraId = perfil.obraId;
    if (obraId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu usuario no tiene una obra asignada.')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await ref
          .read(solicitudAutorizacionRepositoryProvider)
          .crear(
            SolicitudAutorizacion(
              id: '',
              choferId: perfil.id,
              vehiculoId: vehiculo.id,
              obraId: obraId,
              litrosSolicitados: _litros!.toDouble(),
              comentario: _motivoCtrl.text.trim().isEmpty
                  ? null
                  : _motivoCtrl.text.trim(),
              estado: EstadoSolicitud.pendiente,
              creadoEn: DateTime.now(),
              creadoOffline: false,
            ),
          );
      ref.invalidate(solicitudesPorChoferProvider(perfil.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud enviada. Te avisamos en cuanto te autoricen.',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeErrorRed(e, accion: 'enviar la solicitud'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(sesionProvider);
    if (perfil?.vehiculoId == null) {
      return _PantallaError(
        mensaje:
            'Tu perfil no tiene un vehículo asignado. Contacta a tu administrativo.',
      );
    }

    final vehiculoAsync = ref.watch(vehiculoPorIdProvider(perfil!.vehiculoId!));

    return vehiculoAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          _PantallaError(mensaje: 'No se pudo cargar tu vehículo: $error'),
      data: (vehiculo) => _buildConVehiculo(context, perfil, vehiculo),
    );
  }

  Widget _buildConVehiculo(
    BuildContext context,
    Perfil perfil,
    Vehiculo vehiculo,
  ) {
    _combustible ??= vehiculo.tipoCombustible;
    final topeVehiculo = vehiculo.topeLitrosSemanal.toInt();
    _litros ??= topeVehiculo < 20 ? topeVehiculo : 20;
    final excedeTope = _excedeTope(topeVehiculo);

    final precioAsync = ref.watch(precioVigenteProvider(_combustible!));

    final manana = DateTime.now().add(const Duration(days: 1));
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text(
          'Solicitar litros',
          style: TextStyle(color: AppColors.navy),
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Etiqueta('PARA EL DÍA'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    border: Border.all(
                      color: AppColors.borderInput,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    DateFormat("EEEE d 'de' MMMM", 'es_MX').format(manana),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _Etiqueta('COMBUSTIBLE'),
                const SizedBox(height: 8),
                FuelTypeChipSelector(
                  seleccionado: _combustible!,
                  onChanged: (tipo) => setState(() => _combustible = tipo),
                ),
                const SizedBox(height: 28),
                Center(
                  child: StepperControl(
                    valor: _litros!,
                    min: 5,
                    max: topeVehiculo < 5 ? 5 : topeVehiculo,
                    paso: 5,
                    sufijo: 'L',
                    onChanged: (v) => setState(() => _litros = v),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tope del vehículo: $topeVehiculo L/semana',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: precioAsync.when(
                    data: (precio) => Text(
                      'Cuesta aprox. ${formatoMoneda.format(_litros! * precio.precioPorLitro)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    loading: () => const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (error, _) => Text(
                      'No hay un precio vigente configurado para ${_combustible!.etiqueta.toLowerCase()}.',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _Etiqueta(
                  excedeTope
                      ? '¿POR QUÉ? (OBLIGATORIO)'
                      : '¿POR QUÉ? (OPCIONAL)',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _motivoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ej. viaje extra a la planta de agregados',
                  ),
                ),
                if (excedeTope) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      border: Border.all(color: AppColors.warningBorder),
                      borderRadius: BorderRadius.circular(AppRadii.miniCard),
                    ),
                    child: const Text(
                      'Vas arriba del tope semanal del vehículo. El administrativo verá tu motivo antes de autorizar.',
                      style: TextStyle(
                        color: AppColors.warningTextStrong,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          // Row (no ResponsiveCenter/Align) a propósito: en el slot
          // bottomNavigationBar, Scaffold da una altura laxa pero acotada, y
          // un Align/Center sin heightFactor intenta ser "lo más grande
          // posible" en vez de ajustarse al alto natural del botón — eso
          // hacía que este botón se tragara casi toda la altura de la
          // pantalla, empujando el body real (con el resto del formulario)
          // a un espacio casi nulo e invisible. Row solo ocupa la altura de
          // su hijo más alto, sin importar cuánto espacio laxo reciba.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.card - 1),
                    boxShadow: AppShadows.primaryButton,
                  ),
                  child: ElevatedButton(
                    onPressed: _enviando
                        ? null
                        : () => _enviar(perfil, vehiculo, topeVehiculo),
                    child: _enviando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enviar solicitud'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PantallaError extends StatelessWidget {
  const _PantallaError({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text(
          'Solicitar litros',
          style: TextStyle(color: AppColors.navy),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  mensaje,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
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
