import 'package:powersync/powersync.dart';

import '../../models/models.dart';
import '../obra_repository.dart';

/// Decisión de transporte: 100% PowerSync local, sin REST.
///
/// `obras` es de solo lectura desde el cliente (no hay `crear`/`actualizar`
/// en esta interfaz) y ya está en sync-config.yaml para los dos roles: el
/// chofer ve la suya (`chofer_obra_catalogo`) y administrativo todas
/// (`administrativo_global`, rol único sin restricción de obra). Al ser
/// puramente de lectura y ya estar replicada, no hay razón para ir a la API
/// en vez de al catálogo local — y esto además funciona sin conexión, que es
/// justo cuando más se necesita poder ver el nombre de la propia obra.
class PowerSyncObraRepository implements ObraRepository {
  PowerSyncObraRepository({required this.database});

  final PowerSyncDatabase database;

  @override
  Future<Obra> obtenerPorId(String obraId) async {
    final fila = await database.getOptional('SELECT * FROM obras WHERE id = ?', [obraId]);
    if (fila == null) {
      throw StateError('Obra $obraId no encontrada en el catálogo local.');
    }
    return Obra.fromJson(_filaAJson(fila));
  }

  @override
  Future<List<Obra>> listarTodas() async {
    final filas = await database.getAll('SELECT * FROM obras ORDER BY nombre ASC');
    return filas.map((fila) => Obra.fromJson(_filaAJson(fila))).toList();
  }

  Map<String, dynamic> _filaAJson(Map<String, dynamic> fila) => {
        'id': fila['id'],
        'nombre': fila['nombre'],
        'ubicacion': fila['ubicacion'],
        'estado': fila['estado'],
        'fecha_inicio': fila['fecha_inicio'],
        'fecha_fin': fila['fecha_fin'],
      };
}
