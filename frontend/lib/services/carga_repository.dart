import '../models/models.dart';

abstract class CargaRepository {
  /// Igual que las solicitudes: se confirma de inmediato en la UI aunque no haya red.
  Future<void> crear(Carga carga);

  Future<List<Carga>> listarPorChofer(String choferId);

  Future<List<Carga>> listarPorObra(String obraId);

  /// Sube la foto del ticket guardada localmente y regresa la URL pública.
  Future<String> subirFotoTicket(String cargaId, String rutaLocal);
}
