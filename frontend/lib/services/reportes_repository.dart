import '../models/models.dart';

/// Agrupa el acceso a las vistas de solo lectura que alimentan reportes.
abstract class ReportesRepository {
  Future<List<VistaConcentradoCargas>> concentradoCargas({
    required String obraId,
    DateTime? desde,
    DateTime? hasta,
  });

  Future<List<VistaResumenFinancieroSemanal>> resumenFinancieroSemanal({
    required String obraId,
  });

  /// Para finanzas: mismo resumen pero de todas las obras.
  Future<List<VistaResumenFinancieroSemanal>> resumenFinancieroConsolidado();

  Future<VistaConsumoVehiculoSemanal> consumoSemanalDeVehiculo(String vehiculoId);

  /// Presupuesto/fondo semanal de la obra, incluida la semana abierta actual
  /// (`GET /reportes/fondo-semanal`). Orden descendente por periodo_inicio.
  Future<List<FondoSemanal>> fondoSemanalPorObra({required String obraId});
}
