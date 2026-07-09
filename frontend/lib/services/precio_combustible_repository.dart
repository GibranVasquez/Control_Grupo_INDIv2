import '../models/models.dart';

abstract class PrecioCombustibleRepository {
  Future<PrecioCombustible> obtenerVigente(TipoCombustible tipo);

  Future<List<PrecioCombustible>> listarHistorico(TipoCombustible tipo);

  /// Solo finanzas puede dar de alta un nuevo precio vigente.
  Future<void> crear(PrecioCombustible precio);
}
