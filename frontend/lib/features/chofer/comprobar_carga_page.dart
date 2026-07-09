import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../dev/datos_demo.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

class ComprobarCargaPage extends StatefulWidget {
  const ComprobarCargaPage({super.key, required this.solicitud});

  final SolicitudAutorizacion solicitud;

  @override
  State<ComprobarCargaPage> createState() => _ComprobarCargaPageState();
}

class _ComprobarCargaPageState extends State<ComprobarCargaPage> {
  XFile? _fotoTicket;
  num _km = 0;
  late num _litros = widget.solicitud.litrosSolicitados;

  // TODO: traer de precios_combustible / vehiculos.km_actual cuando estén los repositorios.
  static const _precioPorLitro = DatosDemo.precioMagnaPorLitro;
  static const _kmAnterior = 18420;

  Vehiculo get _vehiculo => DatosDemo.vehiculosObra.firstWhere(
    (v) => v.id == widget.solicitud.vehiculoId,
    orElse: () => DatosDemo.vehiculoAsignado,
  );

  bool get _esMaquinaria => _vehiculo.tipoUnidad == TipoUnidad.maquinaria;

  double get _rendimiento => _km <= 0 ? 0 : _km / _litros;

  ({String etiqueta, Color color}) get _semaforoRendimiento {
    final r = _rendimiento;
    if (_esMaquinaria) {
      // Horómetro: L/h fuera de 2–25 se considera atípico para maquinaria pesada.
      if (r < 2 || r > 25) {
        return (etiqueta: '⚠ Revisar', color: AppColors.error);
      }
      if (r > 15) return (etiqueta: 'Alto', color: AppColors.warning);
      return (etiqueta: 'Normal', color: AppColors.success);
    }
    if (r < 3 || r > 15) return (etiqueta: '⚠ Revisar', color: AppColors.error);
    if (r <= 6) return (etiqueta: 'Bajo', color: AppColors.warning);
    return (etiqueta: 'Normal', color: AppColors.success);
  }

  Future<void> _tomarFoto() async {
    final archivo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (archivo != null) setState(() => _fotoTicket = archivo);
  }

  void _enviar() {
    if (_fotoTicket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta la foto del ticket de la gasolinería.'),
        ),
      );
      return;
    }
    // TODO: crear la carga vía CargaRepository — se confirma al instante, queda `creado_offline`
    // hasta que la foto y los datos suban de verdad.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Carga registrada. Se sincronizará automáticamente.'),
      ),
    );
    context.go('/chofer');
  }

  @override
  Widget build(BuildContext context) {
    final vehiculo = _vehiculo;
    final importe = _litros * _precioPorLitro;
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
    final semaforo = _semaforoRendimiento;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text(
          'Comprobar carga',
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DATOS DEL VEHÍCULO',
                        style: TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FilaDato(
                        label: 'Responsable',
                        valor: DatosDemo.perfilChofer.nombreCompleto,
                      ),
                      _FilaDato(label: 'Modelo', valor: vehiculo.descripcion),
                      _FilaDato(
                        label: 'Placas',
                        valor: vehiculo.placa,
                        mono: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _ZonaFoto(foto: _fotoTicket, onTap: _tomarFoto),
                const SizedBox(height: 24),
                Text(
                  _esMaquinaria ? 'HORAS DE OPERACIÓN' : 'KM DEL DÍA',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: StepperControl(
                    valor: _km,
                    min: 0,
                    max: _esMaquinaria ? 24 : 999,
                    paso: 1,
                    grande: false,
                    onChanged: (v) => setState(() => _km = v),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'LITROS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: StepperControl(
                    valor: _litros,
                    min: 1,
                    max: vehiculo.topeLitrosSemanal,
                    paso: 1,
                    grande: false,
                    onChanged: (v) => setState(() => _litros = v),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RENDIMIENTO',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _esMaquinaria
                                  ? '${_rendimiento.toStringAsFixed(1)} L/h'
                                  : '${_rendimiento.toStringAsFixed(1)} km/L',
                              style: AppTypography.mono(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: semaforo.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.badge),
                        ),
                        child: Text(
                          semaforo.etiqueta,
                          style: TextStyle(
                            color: semaforo.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _FilaDesglose(
                  label: 'Costo x litro',
                  valor: formatoMoneda.format(_precioPorLitro),
                ),
                const Divider(color: AppColors.divider, height: 24),
                _FilaDesglose(
                  label: 'Importe',
                  valor: formatoMoneda.format(importe),
                  destacado: true,
                ),
                const Divider(color: AppColors.divider, height: 24),
                _FilaDesglose(
                  label: _esMaquinaria
                      ? 'Horas acumuladas anteriores'
                      : 'Km anterior registrado',
                  valor: _esMaquinaria ? '$_kmAnterior h' : '$_kmAnterior km',
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ResponsiveCenter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _enviar,
              child: const Text('Enviar comprobación'),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({
    required this.label,
    required this.valor,
    this.mono = false,
  });

  final String label;
  final String valor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: mono
                  ? AppTypography.mono(color: Colors.white, fontSize: 14)
                  : const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonaFoto extends StatelessWidget {
  const _ZonaFoto({required this.foto, required this.onTap});

  final XFile? foto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: onTap,
      child: DottedBorderBox(
        child: foto == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tomar foto del ticket',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ticket capturado',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Recuadro con borde punteado — Flutter no lo trae nativo, se dibuja con CustomPaint.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BordePunteadoPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _BordePunteadoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadii.card),
    );
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metric.length) {
        canvas.drawPath(
          metric.extractPath(distancia, distancia + dashWidth),
          paint,
        );
        distancia += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilaDesglose extends StatelessWidget {
  const _FilaDesglose({
    required this.label,
    required this.valor,
    this.destacado = false,
  });

  final String label;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(
          valor,
          style: AppTypography.mono(
            fontSize: destacado ? 24 : 15,
            fontWeight: FontWeight.w600,
            color: destacado ? AppColors.primary : AppColors.navy,
          ),
        ),
      ],
    );
  }
}
