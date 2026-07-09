import '../models/models.dart';

abstract class ObraRepository {
  Future<Obra> obtenerPorId(String obraId);

  /// Solo para finanzas, que ve todas las obras.
  Future<List<Obra>> listarTodas();
}
