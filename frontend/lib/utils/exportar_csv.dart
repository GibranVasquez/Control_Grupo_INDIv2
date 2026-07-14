import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Exporta filas a un .csv en el directorio de documentos del dispositivo
/// (se abre directo en Excel/Sheets — no hace falta una librería de Excel
/// aparte para esto). Usado por las pantallas de reportes de administrativo
/// y finanzas.
///
/// [encabezados] y cada fila de [filas] deben tener la misma longitud.
Future<File> exportarCsv({
  required String nombreBase,
  required List<String> encabezados,
  required List<List<Object?>> filas,
}) async {
  String celda(Object? valor) => '"${(valor ?? '').toString().replaceAll('"', '""')}"';

  final buffer = StringBuffer()..writeln(encabezados.join(','));
  for (final fila in filas) {
    buffer.writeln(fila.map(celda).join(','));
  }

  final directorio = await getApplicationDocumentsDirectory();
  final marcaDeTiempo = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final archivo = File(path.join(directorio.path, '${nombreBase}_$marcaDeTiempo.csv'));
  await archivo.writeAsString(buffer.toString());
  return archivo;
}
