import '../models/models.dart';

abstract class CargaRepository {
  /// Igual que las solicitudes: se confirma de inmediato en la UI aunque no haya red.
  /// Regresa el id real con el que quedó insertada (el repositorio genera su
  /// propio uuid v4, ignorando `carga.id`) — lo necesita el llamador para
  /// subir la foto del ticket justo después con [subirFotoTicket].
  Future<String> crear(Carga carga);

  Future<List<Carga>> listarPorChofer(String choferId);

  Future<List<Carga>> listarPorObra(String obraId);

  /// La carga más reciente de este vehículo (para derivar km/horas anterior
  /// al armar la vista previa de una carga nueva). Nulo si el vehículo nunca
  /// ha tenido una carga registrada. El servidor vuelve a calcular este valor
  /// de forma autoritativa al crear la carga real (ver carga.service.ts); esto
  /// es solo una previsualización en el cliente.
  Future<Carga?> obtenerUltimaPorVehiculo(String vehiculoId);

  /// Sube la foto del ticket guardada localmente y regresa la URL pública.
  Future<String> subirFotoTicket(String cargaId, String rutaLocal);
}
