import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../dev/datos_demo.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

/// Bandeja de solicitudes pendientes de la obra del administrativo.
/// El slider "AUTORIZAR" refleja el diseño original (autorización parcial), pero el
/// esquema actual solo guarda estado autorizado/rechazado — litros_autorizados está
/// pendiente de confirmar con backend en Fase 0. Por ahora el slider solo decide si
/// el comentario es obligatorio; el valor exacto no se persiste todavía.
class BandejaAutorizacionesPage extends StatefulWidget {
  const BandejaAutorizacionesPage({super.key});

  @override
  State<BandejaAutorizacionesPage> createState() => _BandejaAutorizacionesPageState();
}

class _BandejaAutorizacionesPageState extends State<BandejaAutorizacionesPage> {
  late String _seleccionadaId = DatosDemo.solicitudesPendientesObra.first.id;
  final Map<String, num> _valoresSlider = {};
  final Map<String, TextEditingController> _comentarios = {};

  Vehiculo _vehiculoDe(SolicitudAutorizacion s) =>
      DatosDemo.vehiculosObra.firstWhere((v) => v.id == s.vehiculoId);

  Perfil _choferDe(SolicitudAutorizacion s) =>
      DatosDemo.perfilesChoferes.firstWhere((p) => p.id == s.choferId);

  num _valorSlider(SolicitudAutorizacion s) =>
      _valoresSlider[s.id] ?? s.litrosSolicitados;

  TextEditingController _comentarioCtrl(String id) =>
      _comentarios.putIfAbsent(id, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _comentarios.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _resolver(SolicitudAutorizacion solicitud, EstadoSolicitud estado) {
    final comentario = _comentarioCtrl(solicitud.id).text.trim();
    // TODO: SolicitudAutorizacionRepository.resolver(solicitudId, estado, comentario).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          estado == EstadoSolicitud.autorizado ? 'Solicitud autorizada.' : 'Solicitud rechazada.',
        ),
      ),
    );
    setState(() {
      DatosDemo.solicitudesPendientesObra.removeWhere((s) => s.id == solicitud.id);
      if (DatosDemo.solicitudesPendientesObra.isNotEmpty) {
        _seleccionadaId = DatosDemo.solicitudesPendientesObra.first.id;
      }
    });
    debugPrint('comentario capturado: $comentario');
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = DatosDemo.solicitudesPendientesObra;
    final seleccionada = pendientes.where((s) => s.id == _seleccionadaId).firstOrNull;

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
                      if (solicitud.id == _seleccionadaId)
                        _SolicitudExpandida(
                          solicitud: solicitud,
                          chofer: _choferDe(solicitud),
                          vehiculo: _vehiculoDe(solicitud),
                          valorSlider: _valorSlider(solicitud),
                          onSliderChanged: (v) => setState(() => _valoresSlider[solicitud.id] = v),
                          comentarioCtrl: _comentarioCtrl(solicitud.id),
                          onAutorizar: () => _resolver(solicitud, EstadoSolicitud.autorizado),
                          onRechazar: () => _resolver(solicitud, EstadoSolicitud.rechazado),
                        )
                      else
                        _SolicitudColapsada(
                          solicitud: solicitud,
                          chofer: _choferDe(solicitud),
                          vehiculo: _vehiculoDe(solicitud),
                          onTap: () => setState(() => _seleccionadaId = solicitud.id),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        if (seleccionada != null) _PanelReglas(vehiculo: _vehiculoDe(seleccionada)),
      ],
    );
  }
}

class _SolicitudExpandida extends StatelessWidget {
  const _SolicitudExpandida({
    required this.solicitud,
    required this.chofer,
    required this.vehiculo,
    required this.valorSlider,
    required this.onSliderChanged,
    required this.comentarioCtrl,
    required this.onAutorizar,
    required this.onRechazar,
  });

  final SolicitudAutorizacion solicitud;
  final Perfil chofer;
  final Vehiculo vehiculo;
  final num valorSlider;
  final ValueChanged<num> onSliderChanged;
  final TextEditingController comentarioCtrl;
  final VoidCallback onAutorizar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context) {
    final esParcial = valorSlider < solicitud.litrosSolicitados;
    final consumo = DatosDemo.consumoSemanalVehiculo1;

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
                valor: '${consumo.litrosConsumidos.toStringAsFixed(0)} L',
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: esParcial && comentarioCtrl.text.trim().isEmpty ? null : onAutorizar,
                  child: Text('Autorizar ${valorSlider.toStringAsFixed(0)} L'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onRechazar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Rechazar'),
                ),
              ),
            ],
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
  const _PanelReglas({required this.vehiculo});

  final Vehiculo vehiculo;

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 0);
    final ejercido = DatosDemo.presupuestoEjercidoObra;
    final total = DatosDemo.presupuestoSemanalObra;
    final avance = ejercido / total;

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
            valor: 'Si se autoriza menos de lo solicitado',
          ),
          const SizedBox(height: 10),
          _TarjetaRegla(titulo: 'Límite semanal \$', valor: formatoMoneda.format(total)),
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
                Text('${(avance * 100).toStringAsFixed(0)}% ejercido',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
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
