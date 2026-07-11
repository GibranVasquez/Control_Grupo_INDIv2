import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../router/app_router.dart';
import '../../state/providers.dart';
import '../../state/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_shadows.dart';
import '../../widgets/widgets.dart';

class ChoferHomePage extends ConsumerWidget {
  const ChoferHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(sesionProvider);
    if (perfil == null) return const SizedBox.shrink();

    if (perfil.vehiculoId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tu perfil no tiene un vehículo asignado. Contacta a tu administrativo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      );
    }

    final vehiculoAsync = ref.watch(vehiculoPorIdProvider(perfil.vehiculoId!));
    final solicitudesAsync = ref.watch(solicitudesPorChoferProvider(perfil.id));

    if (vehiculoAsync.isLoading || solicitudesAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (vehiculoAsync.hasError) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Text('No se pudo cargar tu vehículo: ${vehiculoAsync.error}'),
          ),
        ),
      );
    }
    if (solicitudesAsync.hasError) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Text('No se pudieron cargar tus solicitudes: ${solicitudesAsync.error}'),
          ),
        ),
      );
    }

    return _ChoferHomeContenido(
      perfil: perfil,
      vehiculo: vehiculoAsync.requireValue,
      solicitudes: solicitudesAsync.requireValue,
    );
  }
}

class _ChoferHomeContenido extends StatelessWidget {
  const _ChoferHomeContenido({
    required this.perfil,
    required this.vehiculo,
    required this.solicitudes,
  });

  final Perfil perfil;
  final Vehiculo vehiculo;
  final List<SolicitudAutorizacion> solicitudes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveCenter(
        maxWidth: 560,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Encabezado(perfil: perfil, vehiculo: vehiculo),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList.list(
                children: [
                  _BotonSolicitar(
                    onTap: () => context.push(AppRoutes.solicitarLitros),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'MIS SOLICITUDES',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (solicitudes.isEmpty)
                    const EstadoVacio(
                      mensaje: 'Todavía no has hecho ninguna solicitud.',
                      icono: Icons.local_gas_station_outlined,
                    )
                  else
                    for (final solicitud in solicitudes) ...[
                      _TarjetaSolicitud(
                        solicitud: solicitud,
                        vehiculo: vehiculo,
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.perfil, required this.vehiculo});

  final Perfil perfil;
  final Vehiculo vehiculo;

  String get _saludo {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buen día';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final primerNombre = perfil.nombreCompleto.split(' ').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_gas_station,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Combustible',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_saludo, $primerNombre',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              AvatarIniciales(nombre: perfil.nombreCompleto),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MI VEHÍCULO',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${vehiculo.descripcion} · ${vehiculo.placa}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonSolicitar extends StatelessWidget {
  const _BotonSolicitar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: AppShadows.primaryButton,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_gas_station, color: Colors.white),
              const SizedBox(width: 10),
              const Text(
                'Solicitar litros para mañana',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud({required this.solicitud, required this.vehiculo});

  final SolicitudAutorizacion solicitud;
  final Vehiculo vehiculo;

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("d 'de' MMMM", 'es_MX').format(solicitud.creadoEn);

    return GestureDetector(
      onTap: solicitud.estado == EstadoSolicitud.autorizado
          ? () =>
                context.push(AppRoutes.respuestaAutorizacion, extra: solicitud)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.mobileCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fecha,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                EstadoSolicitudBadge(estado: solicitud.estado),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${solicitud.litrosSolicitados.toStringAsFixed(0)} L solicitados · ${vehiculo.descripcion}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            if (solicitud.creadoOffline) ...[
              const SizedBox(height: 10),
              const SyncStatusBadge(status: SyncStatus.pendiente),
            ],
          ],
        ),
      ),
    );
  }
}
