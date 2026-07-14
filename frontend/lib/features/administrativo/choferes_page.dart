import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../state/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../utils/errores_red.dart';
import '../../widgets/widgets.dart';

/// Choferes de la obra del administrativo — solo consulta y activar/desactivar acceso.
/// El alta de choferes nuevos la hace finanzas en Usuarios (Fase 5).
class ChoferesPage extends ConsumerStatefulWidget {
  const ChoferesPage({super.key});

  @override
  ConsumerState<ChoferesPage> createState() => _ChoferesPageState();
}

class _ChoferesPageState extends ConsumerState<ChoferesPage> {
  final Set<String> _actualizando = {};

  Future<void> _alternarActivo(String obraId, Perfil perfil) async {
    setState(() => _actualizando.add(perfil.id));
    try {
      await ref.read(perfilRepositoryProvider).actualizarActivo(perfil.id, !perfil.activo);
      ref.invalidate(perfilesPorObraProvider(obraId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeErrorRed(e, accion: 'actualizar el acceso'))),
      );
    } finally {
      if (mounted) setState(() => _actualizando.remove(perfil.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final obraId = ref.watch(sesionProvider)?.obraId;
    if (obraId == null) {
      return const Center(
        child: Text('Tu usuario no tiene una obra asignada.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final perfilesAsync = ref.watch(perfilesPorObraProvider(obraId));
    final solicitudesAsync = ref.watch(solicitudesPendientesObraProvider(obraId));

    if (perfilesAsync.isLoading || solicitudesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = perfilesAsync.error ?? solicitudesAsync.error;
    if (error != null) {
      return Center(child: Text('No se pudieron cargar los choferes: $error'));
    }

    final choferes = perfilesAsync.requireValue.where((p) => p.rol == RolUsuario.chofer).toList();
    final pendientes = solicitudesAsync.requireValue;
    int solicitudesAbiertasDe(String choferId) =>
        pendientes.where((s) => s.choferId == choferId).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choferes',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.navy)),
          const SizedBox(height: 20),
          Expanded(
            child: choferes.isEmpty
                ? const EstadoVacio(
                    mensaje: 'No hay choferes registrados en esta obra.',
                    icono: Icons.people_outline_rounded,
                  )
                : ListView.separated(
                    itemCount: choferes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final chofer = choferes[i];
                      final actualizando = _actualizando.contains(chofer.id);
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            AvatarIniciales(nombre: chofer.nombreCompleto, background: AppColors.textTertiary),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(chofer.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(chofer.numeroEmpleado,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                                ],
                              ),
                            ),
                            Text(
                              '${solicitudesAbiertasDe(chofer.id)} solicitudes pendientes',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                            ),
                            const SizedBox(width: 16),
                            actualizando
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Switch(
                                    value: chofer.activo,
                                    onChanged: (_) => _alternarActivo(obraId, chofer),
                                  ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
