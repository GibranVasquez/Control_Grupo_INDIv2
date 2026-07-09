import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class FuelTypeChipSelector extends StatelessWidget {
  const FuelTypeChipSelector({
    super.key,
    required this.seleccionado,
    required this.onChanged,
  });

  final TipoCombustible seleccionado;
  final ValueChanged<TipoCombustible> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TipoCombustible.values.map((tipo) {
        final activo = tipo == seleccionado;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: tipo == TipoCombustible.values.last ? 0 : 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.input),
              onTap: () => onChanged(tipo),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activo ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  border: Border.all(
                    color: activo ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  tipo.etiqueta,
                  style: TextStyle(
                    color: activo ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
