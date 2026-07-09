import 'package:flutter/material.dart';

import '../../dev/datos_demo.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/widgets.dart';

/// Choferes de la obra del administrativo — solo consulta y activar/desactivar acceso.
/// El alta de choferes nuevos la hace finanzas en Usuarios (Fase 5).
class ChoferesPage extends StatefulWidget {
  const ChoferesPage({super.key});

  @override
  State<ChoferesPage> createState() => _ChoferesPageState();
}

class _ChoferesPageState extends State<ChoferesPage> {
  late List<Perfil> _choferes = List.of(DatosDemo.perfilesChoferes);

  int _solicitudesAbiertasDe(String choferId) => DatosDemo.solicitudesPendientesObra
      .where((s) => s.choferId == choferId)
      .length;

  void _alternarActivo(Perfil perfil) {
    // TODO: PerfilRepository.actualizarActivo(perfil.id, !perfil.activo).
    setState(() {
      _choferes = [
        for (final c in _choferes)
          if (c.id == perfil.id)
            Perfil(
              id: c.id,
              authUserId: c.authUserId,
              numeroEmpleado: c.numeroEmpleado,
              nombreCompleto: c.nombreCompleto,
              rol: c.rol,
              obraId: c.obraId,
              activo: !c.activo,
            )
          else
            c,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choferes',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.navy)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _choferes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final chofer = _choferes[i];
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
                        '${_solicitudesAbiertasDe(chofer.id)} solicitudes pendientes',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                      ),
                      const SizedBox(width: 16),
                      Switch(
                        value: chofer.activo,
                        onChanged: (_) => _alternarActivo(chofer),
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
