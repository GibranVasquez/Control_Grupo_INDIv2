import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../state/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

/// Bandeja de solicitudes pendientes de la obra del administrativo.
class BandejaAutorizacionesPage extends ConsumerStatefulWidget {
  const BandejaAutorizacionesPage({super.key});

  @override
  ConsumerState<BandejaAutorizacionesPage> createState() => _BandejaAutorizacionesPageState();
}

class _BandejaAutorizacionesPageState extends ConsumerState<BandejaAutorizacionesPage> {
  String? _seleccionadaId;
  final Map<String, num> _valoresSlider = {};
  final Map<String, TextEditingController> _comentarios = {};
  final Set<String> _resolviendo = {};

  num _valorSlider(SolicitudAutorizacion s) => _valoresSlider[s.id] ?? s.litrosSolicitados;

  TextEditingController _comentarioCtrl(String id) =>
      _comentarios.putIfAbsent(id, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _comentarios.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _resolver(String obraId, SolicitudAutorizacion solicitud, EstadoSolicitud estado) async {
    final comentario = _comentarioCtrl(solicitud.id).text.trim();
    setState(() => _resolviendo.add(solicitud.id));
    try {
      await ref.read(solicitudAutorizacionRepositoryProvider).resolver(
            solicitudId: solicitud.id,
            estado: estado,
            comentario: comentario.isEmpty ? null : comentario,
            litrosAutorizados: estado == EstadoSolicitud.autorizado ? _valorSlider(solicitud).toDouble() : null,
          );
      ref.invalidate(solicitudesPendientesObraProvider(obraId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            estado == EstadoSolicitud.autorizado ? 'Solicitud autorizada.' : 'Solicitud rechazada.',
          ),
        ),
      );
      setState(() {
        _valoresSlider.remove(solicitud.id);
        _comentarios.remove(solicitud.id)?.dispose();
        if (_seleccionadaId == solicitud.id) _seleccionadaId = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo resolver la solicitud: $e')),
      );
    } finally {
      if (mounted) setState(() => _resolviendo.remove(solicitud.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(sesionProvider);
    final obraId = perfil?.obraId;
    if (obraId == null) {
      return const Center(
        child: Text('Tu usuario no tiene una obra asignada.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final solicitudesAsync = ref.watch(solicitudesPendientesObraProvider(obraId));
    final perfilesAsync = ref.watch(perfilesPorObraProvider(obraId));
    final vehiculosAsync = ref.watch(vehiculosPorObraProvider(obraId));
    final fondoAsync = ref.watch(fondoSemanalObraProvider(obraId));

    if (solicitudesAsync.isLoading || perfilesAsync.isLoading || vehiculosAsync.isLoading || fondoAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = solicitudesAsync.error ?? perfilesAsync.error ?? vehiculosAsync.error ?? fondoAsync.error;
    if (error != null) {
      return Center(child: Text('No se pudo cargar la bandeja: $error'));
    }

    final pendientes = solicitudesAsync.requireValue;
    final perfiles = perfilesAsync.requireValue;
    final vehiculos = vehiculosAsync.requireValue;
    final fondos = fondoAsync.requireValue;

    if (_seleccionadaId != null && !pendientes.any((s) => s.id == _seleccionadaId)) {
      _seleccionadaId = null;
    }
    _seleccionadaId ??= pendientes.isEmpty ? null : pendientes.first.id;

    Perfil? choferDe(SolicitudAutorizacion s) => perfiles.where((p) => p.id == s.choferId).firstOrNull;
    Vehiculo? vehiculoDe(SolicitudAutorizacion s) => vehiculos.where((v) => v.id == s.vehiculoId).firstOrNull;

    final seleccionada = pendientes.where((s) => s.id == _seleccionadaId).firstOrNull;
    final vehiculoSeleccionado = seleccionada == null ? null : vehiculoDe(seleccionada);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: pendientes.isEmpty
              ? const Center(
                  child: Text('No hay solicitudes pendientes.', style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text('Bandeja de autorizaciones',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.navy)),
                    const SizedBox(height: 20),
                    for (final solicitud in pendientes) ...[
                      Builder(
                        builder: (context) {
                          final chofer = choferDe(solicitud);
                          final vehiculo = vehiculoDe(solicitud);
                          if (chofer == null || vehiculo == null) {
                            return _SolicitudSinDatos(solicitud: solicitud);
                          }
                          if (solicitud.id == _seleccionadaId) {
                            return _SolicitudExpandida(
                              solicitud: solicitud,
                              chofer: chofer,
                              vehiculo: vehiculo,
                              valorSlider: _valorSlider(solicitud),
                              onSliderChanged: (v) => setState(() => _valoresSlider[solicitud.id] = v),
                              comentarioCtrl: _comentarioCtrl(solicitud.id),
                              resolviendo: _resolviendo.contains(solicitud.id),
                              onAutorizar: () => _resolver(obraId, solicitud, EstadoSolicitud.autorizado),
                              onRechazar: () => _resolver(obraId, solicitud, EstadoSolicitud.rechazado),
                            );
                          }
                          return _SolicitudColapsada(
                            solicitud: solicitud,
                            chofer: chofer,
                            vehiculo: vehiculo,
                            onTap: () => setState(() => _seleccionadaId = solicitud.id),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        if (vehiculoSeleccionado != null) _PanelReglas(vehiculo: vehiculoSeleccionado, fondos: fondos),
      ],
    );
  }
}

class _SolicitudSinDatos extends StatelessWidget {
  const _SolicitudSinDatos({required this.solicitud});

  final SolicitudAutorizacion solicitud;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        border: Border.all(color: AppColors.errorBorder),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Text(
        'No se pudo cargar el chofer o vehículo de la solicitud ${solicitud.id}.',
        style: const TextStyle(color: AppColors.error),
      ),
    );
  }
}

class _SolicitudExpandida extends ConsumerWidget {
  const _SolicitudExpandida({
    required this.solicitud,
    required this.chofer,
    required this.vehiculo,
    required this.valorSlider,
    required this.onSliderChanged,
    required this.comentarioCtrl,
    required this.resolviendo,
    required this.onAutorizar,
    required this.onRechazar,
  });

  final SolicitudAutorizacion solicitud;
  final Perfil chofer;
  final Vehiculo vehiculo;
  final num valorSlider;
  final ValueChanged<num> onSliderChanged;
  final TextEditingController comentarioCtrl;
  final bool resolviendo;
  final VoidCallback onAutorizar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esParcial = valorSlider < solicitud.litrosSolicitados;
    final consumoAsync = ref.watch(consumoSemanalVehiculoProvider(vehiculo.id));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarIniciales(nombre: chofer.nombreCompleto, background: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chofer.nombreCompleto,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      '${vehiculo.descripcion} · ${vehiculo.placa} · ${vehiculo.tipoCombustible.etiqueta}',
                      style: AppTypography.mono(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const EstadoSolicitudBadge(estado: EstadoSolicitud.pendiente),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _MiniCard(label: 'SOLICITADO', valor: '${solicitud.litrosSolicitados.toStringAsFixed(0)} L'),
              const SizedBox(width: 10),
              _MiniCard(label: 'TOPE VEHÍCULO', valor: '${vehiculo.topeLitrosSemanal.toStringAsFixed(0)} L'),
              const SizedBox(width: 10),
              _MiniCard(
                label: 'CONSUMO SEMANA',
                valor: consumoAsync.when(
                  data: (c) => '${c.litrosConsumidos.toStringAsFixed(0)} L',
                  loading: () => '…',
                  error: (_, _) => '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AUTORIZAR',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
              Text('${valorSlider.toStringAsFixed(0)} L',
                  style: AppTypography.mono(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          Slider(
            value: valorSlider.toDouble(),
            min: 0,
            max: solicitud.litrosSolicitados.clamp(5, 999).toDouble(),
            divisions: (solicitud.litrosSolicitados / 5).round().clamp(1, 999),
            activeColor: AppColors.primary,
            onChanged: (v) => onSliderChanged(v),
          ),
          if (esParcial) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                border: Border.all(color: AppColors.errorBorder),
                borderRadius: BorderRadius.circular(AppRadii.miniCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠ COMENTARIO OBLIGATORIO',
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: comentarioCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Explica por qué se autoriza menos de lo solicitado',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // ListenableBuilder para que Autorizar/Rechazar reaccionen en cada
          // tecleo del comentario, no solo en el primer build (comentarioCtrl
          // no dispara setState por sí solo).
          ListenableBuilder(
            listenable: comentarioCtrl,
            builder: (context, _) {
              final comentarioVacio = comentarioCtrl.text.trim().isEmpty;
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: resolviendo || (esParcial && comentarioVacio) ? null : onAutorizar,
                      child: resolviendo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Autorizar ${valorSlider.toStringAsFixed(0)} L'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: resolviendo ? null : onRechazar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadii.miniCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 10.5)),
            const SizedBox(height: 4),
            Text(valor, style: AppTypography.mono(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _SolicitudColapsada extends StatelessWidget {
  const _SolicitudColapsada({
    required this.solicitud,
    required this.chofer,
    required this.vehiculo,
    required this.onTap,
  });

  final SolicitudAutorizacion solicitud;
  final Perfil chofer;
  final Vehiculo vehiculo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            AvatarIniciales(nombre: chofer.nombreCompleto, diametro: 36, background: AppColors.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chofer.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${vehiculo.descripcion} · ${vehiculo.placa}',
                      style: AppTypography.mono(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text('${solicitud.litrosSolicitados.toStringAsFixed(0)} L',
                style: AppTypography.mono(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _PanelReglas extends StatelessWidget {
  const _PanelReglas({required this.vehiculo, required this.fondos});

  final Vehiculo vehiculo;
  final List<FondoSemanal> fondos;

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 0);
    // fondoSemanalPorObra ordena desc por periodo_inicio: el primero es la
    // semana más reciente (la abierta actual, si finanzas ya la capturó).
    final fondoActual = fondos.firstOrNull;
    final ejercido = fondoActual?.consumo ?? 0;
    final total = fondoActual == null
        ? 0.0
        : (fondoActual.montoDepositado > 0 ? fondoActual.montoDepositado : fondoActual.montoSolicitado);
    final avance = total <= 0 ? 0.0 : ejercido / total;

    return Container(
      width: 270,
      padding: const EdgeInsets.all(20),
      color: AppColors.surfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reglas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),
          _TarjetaRegla(titulo: 'Tope por vehículo', valor: '${vehiculo.topeLitrosSemanal.toStringAsFixed(0)} L / semana'),
          const SizedBox(height: 10),
          const _TarjetaRegla(
            titulo: 'Comentario obligatorio',
            valor: 'Al rechazar, o si se autoriza menos de lo solicitado',
          ),
          const SizedBox(height: 10),
          _TarjetaRegla(
            titulo: 'Límite semanal \$',
            valor: fondoActual == null ? 'Sin capturar todavía' : formatoMoneda.format(total),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF0A3FB0)]),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PRESUPUESTO DE LA SEMANA',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11)),
                const SizedBox(height: 6),
                Text(
                  fondoActual == null ? 'Sin datos de fondo semanal' : '${(avance * 100).toStringAsFixed(0)}% ejercido',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: avance.clamp(0, 1).toDouble(),
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${formatoMoneda.format(ejercido)} de ${formatoMoneda.format(total)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaRegla extends StatelessWidget {
  const _TarjetaRegla({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.miniCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        ],
      ),
    );
  }
}
