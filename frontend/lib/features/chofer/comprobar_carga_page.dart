import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

class ComprobarCargaPage extends ConsumerStatefulWidget {
  const ComprobarCargaPage({super.key, required this.solicitud});

  final SolicitudAutorizacion solicitud;

  @override
  ConsumerState<ComprobarCargaPage> createState() => _ComprobarCargaPageState();
}

class _ComprobarCargaPageState extends ConsumerState<ComprobarCargaPage> {
  XFile? _fotoTicket;
  num _recorrido = 0;
  late num _litros = widget.solicitud.litrosAutorizados ?? widget.solicitud.litrosSolicitados;
  bool _enviando = false;

  Future<void> _tomarFoto() async {
    final archivo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (archivo != null) setState(() => _fotoTicket = archivo);
  }

  ({String etiqueta, Color color}) _semaforoRendimiento(double rendimiento, bool esMaquinaria) {
    if (esMaquinaria) {
      // Horómetro: L/h fuera de 2–25 se considera atípico para maquinaria pesada.
      if (rendimiento < 2 || rendimiento > 25) {
        return (etiqueta: '⚠ Revisar', color: AppColors.error);
      }
      if (rendimiento > 15) return (etiqueta: 'Alto', color: AppColors.warning);
      return (etiqueta: 'Normal', color: AppColors.success);
    }
    if (rendimiento < 3 || rendimiento > 15) return (etiqueta: '⚠ Revisar', color: AppColors.error);
    if (rendimiento <= 6) return (etiqueta: 'Bajo', color: AppColors.warning);
    return (etiqueta: 'Normal', color: AppColors.success);
  }

  Future<bool> _confirmarSinRecorrido(bool esMaquinaria) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Sin actividad registrada?'),
        content: Text(
          esMaquinaria
              ? 'No registraste horas de operación hoy. ¿Confirmas que la maquinaria no operó antes de esta carga?'
              : 'No registraste kilómetros recorridos hoy. ¿Confirmas que el vehículo no se movió antes de esta carga?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, continuar'),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  Future<void> _enviar({
    required Vehiculo vehiculo,
    required double precioPorLitro,
    required Carga? ultimaCarga,
  }) async {
    if (_fotoTicket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta la foto del ticket de la gasolinería.'),
        ),
      );
      return;
    }

    final esMaquinaria = vehiculo.tipoUnidad == TipoUnidad.maquinaria;
    if (_recorrido <= 0) {
      final confirma = await _confirmarSinRecorrido(esMaquinaria);
      if (!confirma) return;
    }

    setState(() => _enviando = true);
    try {
      final anterior = esMaquinaria ? (ultimaCarga?.horasActual ?? 0) : (ultimaCarga?.kmActual ?? 0);
      final actual = anterior + _recorrido.toInt();

      final cargaId = await ref.read(cargaRepositoryProvider).crear(
            Carga(
              id: '',
              solicitudId: widget.solicitud.id,
              choferId: widget.solicitud.choferId,
              vehiculoId: vehiculo.id,
              obraId: widget.solicitud.obraId,
              litros: _litros.toDouble(),
              precioPorLitro: precioPorLitro,
              montoTotal: _litros * precioPorLitro,
              kmActual: esMaquinaria ? null : actual,
              kmAnterior: esMaquinaria ? null : anterior,
              horasActual: esMaquinaria ? actual : null,
              horasAnterior: esMaquinaria ? anterior : null,
              fechaCarga: DateTime.now(),
              creadoOffline: false,
            ),
          );

      final rutaFoto = _fotoTicket!.path;
      final subioFoto = await _subirFotoConReintentos(cargaId, rutaFoto);
      if (!subioFoto) {
        // Sin conexión (o la carga todavía no sincronizó): se encola para
        // subirse sola en cuanto la app detecte conexión de nuevo, sin que el
        // chofer tenga que volver a esta pantalla (ver
        // colaFotosTicketWatcherProvider en state/providers.dart).
        await ref.read(colaFotosTicketServiceProvider).agregar(cargaId: cargaId, rutaLocal: rutaFoto);
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subioFoto
                ? 'Carga registrada y ticket subido correctamente.'
                : 'Carga registrada. El ticket se subirá automáticamente en cuanto se recupere la conexión.',
          ),
        ),
      );
      context.go('/chofer');
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la carga: $e')),
      );
    }
  }

  /// La subida de la foto requiere que el backend ya tenga la fila de la
  /// carga (POST /cargas/:id/foto-ticket, ver carga_repository.dart), pero
  /// crear() es local-first: puede tardar un instante en sincronizarse. Se
  /// reintenta unas pocas veces con espera corta antes de rendirse; si de
  /// todos modos falla (sin conexión), queda en la cola persistente que
  /// `colaFotosTicketWatcherProvider` vacía sola al reconectar.
  Future<bool> _subirFotoConReintentos(String cargaId, String rutaLocal) async {
    const intentos = 4;
    for (var i = 0; i < intentos; i++) {
      try {
        await ref.read(cargaRepositoryProvider).subirFotoTicket(cargaId, rutaLocal);
        return true;
      } catch (_) {
        if (i == intentos - 1) return false;
        await Future.delayed(Duration(milliseconds: 600 * (i + 1)));
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final vehiculoAsync = ref.watch(vehiculoPorIdProvider(widget.solicitud.vehiculoId));

    return vehiculoAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => _PantallaError(
        mensaje: 'No se encontró el vehículo de esta solicitud. No se puede comprobar la carga.\n($error)',
      ),
      data: (vehiculo) => Consumer(
        builder: (context, ref, _) {
          final precioAsync = ref.watch(precioVigenteProvider(vehiculo.tipoCombustible));
          final ultimaCargaAsync = ref.watch(ultimaCargaPorVehiculoProvider(vehiculo.id));

          if (precioAsync.isLoading || ultimaCargaAsync.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (precioAsync.hasError) {
            return _PantallaError(
              mensaje:
                  'No hay un precio vigente configurado para ${vehiculo.tipoCombustible.etiqueta.toLowerCase()}.',
            );
          }
          if (ultimaCargaAsync.hasError) {
            return _PantallaError(mensaje: 'No se pudo consultar el historial de este vehículo.');
          }

          return _Formulario(
            solicitud: widget.solicitud,
            vehiculo: vehiculo,
            precioPorLitro: precioAsync.requireValue.precioPorLitro,
            ultimaCarga: ultimaCargaAsync.requireValue,
            fotoTicket: _fotoTicket,
            recorrido: _recorrido,
            litros: _litros,
            enviando: _enviando,
            onTomarFoto: _tomarFoto,
            onRecorridoChanged: (v) => setState(() => _recorrido = v),
            onLitrosChanged: (v) => setState(() => _litros = v),
            semaforo: _semaforoRendimiento,
            onEnviar: (precio, ultimaCarga) => _enviar(
              vehiculo: vehiculo,
              precioPorLitro: precio,
              ultimaCarga: ultimaCarga,
            ),
          );
        },
      ),
    );
  }
}

class _Formulario extends StatelessWidget {
  const _Formulario({
    required this.solicitud,
    required this.vehiculo,
    required this.precioPorLitro,
    required this.ultimaCarga,
    required this.fotoTicket,
    required this.recorrido,
    required this.litros,
    required this.enviando,
    required this.onTomarFoto,
    required this.onRecorridoChanged,
    required this.onLitrosChanged,
    required this.semaforo,
    required this.onEnviar,
  });

  final SolicitudAutorizacion solicitud;
  final Vehiculo vehiculo;
  final double precioPorLitro;
  final Carga? ultimaCarga;
  final XFile? fotoTicket;
  final num recorrido;
  final num litros;
  final bool enviando;
  final VoidCallback onTomarFoto;
  final ValueChanged<num> onRecorridoChanged;
  final ValueChanged<num> onLitrosChanged;
  final ({String etiqueta, Color color}) Function(double rendimiento, bool esMaquinaria) semaforo;
  final Future<void> Function(double precioPorLitro, Carga? ultimaCarga) onEnviar;

  bool get _esMaquinaria => vehiculo.tipoUnidad == TipoUnidad.maquinaria;

  double get _rendimiento => recorrido <= 0 ? 0 : recorrido / litros;

  @override
  Widget build(BuildContext context) {
    final importe = litros * precioPorLitro;
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
    final semaforoActual = semaforo(_rendimiento, _esMaquinaria);
    final anterior = _esMaquinaria ? (ultimaCarga?.horasActual ?? 0) : (ultimaCarga?.kmActual ?? 0);

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
                _ZonaFoto(foto: fotoTicket, onTap: onTomarFoto),
                const SizedBox(height: 24),
                Text(
                  _esMaquinaria ? 'HORAS DE OPERACIÓN DE HOY' : 'KM DEL DÍA',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: StepperControl(
                    valor: recorrido,
                    min: 0,
                    max: _esMaquinaria ? 24 : 999,
                    paso: 1,
                    grande: false,
                    onChanged: onRecorridoChanged,
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
                    valor: litros,
                    min: 1,
                    max: vehiculo.topeLitrosSemanal,
                    paso: 1,
                    grande: false,
                    onChanged: onLitrosChanged,
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
                          color: semaforoActual.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.badge),
                        ),
                        child: Text(
                          semaforoActual.etiqueta,
                          style: TextStyle(
                            color: semaforoActual.color,
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
                  valor: formatoMoneda.format(precioPorLitro),
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
                  valor: _esMaquinaria ? '$anterior h' : '$anterior km',
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
              onPressed: enviando ? null : () => onEnviar(precioPorLitro, ultimaCarga),
              child: enviando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('Enviar comprobación'),
            ),
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
        title: const Text('Comprobar carga', style: TextStyle(color: AppColors.navy)),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                const SizedBox(height: 12),
                Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
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
