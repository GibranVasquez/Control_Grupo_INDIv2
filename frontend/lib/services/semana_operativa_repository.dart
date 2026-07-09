import '../models/models.dart';

abstract class SemanaOperativaRepository {
  Future<SemanaOperativa> obtenerActual();

  /// El backend valida que no se pueda reabrir ni volver a cerrar; aquí solo se dispara la llamada.
  Future<void> cerrar(String semanaId);
}
