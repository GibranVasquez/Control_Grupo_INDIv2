import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../dev/datos_demo.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_shadows.dart';
import '../../widgets/widgets.dart';

class SolicitarLitrosPage extends StatefulWidget {
  const SolicitarLitrosPage({super.key});

  @override
  State<SolicitarLitrosPage> createState() => _SolicitarLitrosPageState();
}

class _SolicitarLitrosPageState extends State<SolicitarLitrosPage> {
  late TipoCombustible _combustible = DatosDemo.vehiculoAsignado.tipoCombustible;
  num _litros = 20;
  final _motivoCtrl = TextEditingController();

  // TODO: traer de precios_combustible cuando esté conectado el repositorio.
  static const _precioPorLitro = DatosDemo.precioMagnaPorLitro;

  int get _topeVehiculo => DatosDemo.vehiculoAsignado.topeLitrosSemanal.toInt();

  bool get _excedeTope => _litros > _topeVehiculo;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  void _enviar() {
    if (_excedeTope && _motivoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuéntanos por qué necesitas más litros del tope.')),
      );
      return;
    }
    // TODO: crear la solicitud vía SolicitudAutorizacionRepository (confirma al instante, offline-first).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud enviada. Te avisamos en cuanto te autoricen.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final manana = DateTime.now().add(const Duration(days: 1));
    final importeEstimado = _litros * _precioPorLitro;
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text('Solicitar litros', style: TextStyle(color: AppColors.navy)),
      ),
      body: SafeArea(
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
                  border: Border.all(color: AppColors.borderInput, width: 1.5),
                ),
                child: Text(
                  DateFormat("EEEE d 'de' MMMM", 'es_MX').format(manana),
                  style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              const _Etiqueta('COMBUSTIBLE'),
              const SizedBox(height: 8),
              FuelTypeChipSelector(
                seleccionado: _combustible,
                onChanged: (tipo) => setState(() => _combustible = tipo),
              ),
              const SizedBox(height: 28),
              Center(
                child: StepperControl(
                  valor: _litros,
                  min: 5,
                  max: _topeVehiculo,
                  paso: 5,
                  sufijo: 'L',
                  onChanged: (v) => setState(() => _litros = v),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tope del vehículo: $_topeVehiculo L/semana',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Cuesta aprox. ${formatoMoneda.format(importeEstimado)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _Etiqueta(_excedeTope ? '¿POR QUÉ? (OBLIGATORIO)' : '¿POR QUÉ? (OPCIONAL)'),
              const SizedBox(height: 8),
              TextField(
                controller: _motivoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ej. viaje extra a la planta de agregados',
                ),
              ),
              if (_excedeTope) ...[
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
                    style: TextStyle(color: AppColors.warningTextStrong, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card - 1),
              boxShadow: AppShadows.primaryButton,
            ),
            child: ElevatedButton(
              onPressed: _enviar,
              child: const Text('Enviar solicitud'),
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
