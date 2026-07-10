import '../models/models.dart';

abstract class SemanaOperativaRepository {
  /// [obraId] es obligatorio en el backend solo para finanzas (que no está
  /// atado a una sola obra); para chofer/administrativo el backend resuelve
  /// la obra del token y este parámetro se ignora. Parámetro opcional
  /// agregado sobre la interfaz original: sin él, la pantalla de finanzas
  /// (cierre_semanal_page.dart) no tendría forma de pedir la semana de una
  /// obra concreta.
  Future<SemanaOperativa> obtenerActual({String? obraId});

  /// El backend valida que no se pueda reabrir ni volver a cerrar; aquí solo se dispara la llamada.
  Future<void> cerrar(String semanaId);
}
