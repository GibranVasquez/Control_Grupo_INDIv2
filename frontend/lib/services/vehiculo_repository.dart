import '../models/models.dart';

abstract class VehiculoRepository {
  Future<List<Vehiculo>> listarPorObra(String obraId);

  Future<Vehiculo> obtenerPorId(String vehiculoId);

  Future<void> crear(Vehiculo vehiculo);

  Future<void> actualizar(Vehiculo vehiculo);
}
