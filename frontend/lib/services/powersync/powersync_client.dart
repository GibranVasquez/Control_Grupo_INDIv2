import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import '../api/api_client.dart';
import '../api/token_storage.dart';
import 'powersync_schema.dart';

/// Endpoint del servicio PowerSync self-hosted (backend/powersync/), NO el de
/// la API REST (ver services/api/api_client.dart para ese otro endpoint).
/// Configurable con `--dart-define=POWERSYNC_URL=https://...`; por defecto
/// apunta al servicio local (docker compose en backend/powersync/, puerto
/// 8080 — ver backend/powersync/POWERSYNC.md).
const powerSyncUrl = String.fromEnvironment(
  'POWERSYNC_URL',
  defaultValue: 'http://localhost:8080',
);

/// Abre (o crea) el archivo SQLite local de PowerSync.
///
/// Debe resolverse una sola vez, antes de `runApp` (mismo patrón que
/// `sharedPreferencesProvider` en catalogos_provider.dart/main.dart: la ruta
/// del archivo requiere I/O async de path_provider, que no puede resolverse
/// dentro de un `Provider` síncrono, así que el resultado se inyecta luego
/// con `overrideWithValue`).
Future<PowerSyncDatabase> abrirBaseDeDatosPowerSync() async {
  final directorio = await getApplicationSupportDirectory();
  final rutaArchivo = path.join(directorio.path, 'gi-control-combustible.db');
  final base = PowerSyncDatabase(schema: powerSyncSchema, path: rutaArchivo);
  await base.initialize();
  return base;
}

/// Conector que traduce entre PowerSync (SQLite local) y nuestra API REST.
///
/// - [fetchCredentials]: PowerSync no tiene login propio; reutiliza el mismo
///   JWT que ya emitió `POST /auth/login` (ver [TokenStorage]) sin pedir una
///   autenticación aparte (backend/powersync/POWERSYNC.md, sección 2).
/// - [uploadData]: traduce cada entrada de la cola de escritura local a la
///   llamada REST equivalente. Solo `solicitudes_autorizacion` (insertar,
///   resolver) y `cargas` (insertar) generan escrituras locales; el resto de
///   las tablas del esquema son catálogos de solo lectura (ver
///   powersync_schema.dart) y nunca deberían aparecer aquí.
class ApiPowerSyncConnector extends PowerSyncBackendConnector {
  ApiPowerSyncConnector({required this.tokenStorage, required this.apiClient});

  final TokenStorage tokenStorage;
  final ApiClient apiClient;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final token = await tokenStorage.leer();
    if (token == null) return null;
    return PowerSyncCredentials(endpoint: powerSyncUrl, token: token);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final lote = await database.getCrudBatch();
    if (lote == null) return;

    for (final entrada in lote.crud) {
      await _subirEntrada(database, entrada);
    }
    await lote.complete();
  }

  Future<void> _subirEntrada(PowerSyncDatabase database, CrudEntry entrada) {
    switch (entrada.table) {
      case 'solicitudes_autorizacion':
        return _subirSolicitud(database, entrada);
      case 'cargas':
        return _subirCarga(database, entrada);
      default:
        // vehiculos/obras/perfiles/precios_combustible son catálogos de solo
        // lectura para el cliente (ver powersync_schema.dart): ningún
        // repositorio debería escribir en ellos localmente. Si de todos
        // modos aparece una entrada, se descarta para no bloquear la cola
        // de subida indefinidamente con un op que nunca vamos a poder subir.
        return Future.value();
    }
  }

  /// El backend genera su propio `id` al crear una solicitud/carga (no
  /// acepta uno del cliente — ver backend/src/services/solicitudAutorizacion.service.ts
  /// y carga.service.ts), así que el id generado localmente al insertar
  /// offline (ver PowerSyncSolicitudAutorizacionRepository/PowerSyncCargaRepository)
  /// nunca coincidirá con el id real que asigna Postgres.
  ///
  /// Para no dejar un duplicado permanente en la tabla local, se borra la
  /// fila optimista apenas el POST tiene éxito; la fila real llega poco
  /// después por el flujo normal de descarga de PowerSync, ya con su id
  /// definitivo. Esto deja una ventana breve (entre el borrado local y la
  /// siguiente descarga) en la que el registro recién creado desaparece de
  /// la UI. Se resuelve de raíz solo si el backend acepta un `id` opcional
  /// en el body de esos dos endpoints y lo usa al crear — pendiente,
  /// señalado en el resumen de esta migración.
  Future<void> _subirSolicitud(PowerSyncDatabase database, CrudEntry entrada) async {
    switch (entrada.op) {
      case UpdateType.put:
        final datos = entrada.opData ?? const <String, dynamic>{};
        await apiClient.dio.post('/solicitudes-autorizacion', data: {
          'vehiculo_id': datos['vehiculo_id'],
          'litros_solicitados': datos['litros_solicitados'],
          if (datos['comentario'] != null) 'comentario': datos['comentario'],
          if (datos['actividad'] != null) 'actividad': datos['actividad'],
          if (datos['responsable'] != null) 'responsable': datos['responsable'],
          'creado_offline': datos['creado_offline'] == 1,
        });
        await database.execute(
          'DELETE FROM solicitudes_autorizacion WHERE id = ?',
          [entrada.id],
        );
        return;
      case UpdateType.patch:
        // Único update que la app dispara sobre esta tabla: resolver().
        final datos = entrada.opData ?? const <String, dynamic>{};
        await apiClient.dio.put('/solicitudes-autorizacion/${entrada.id}/resolver', data: {
          'estado': datos['estado'],
          if (datos['litros_autorizados'] != null) 'litros_autorizados': datos['litros_autorizados'],
          if (datos['comentario'] != null) 'comentario': datos['comentario'],
        });
        return;
      case UpdateType.delete:
        // Solo llega aquí por el borrado de reconciliación de arriba; nunca
        // por acción del usuario (no existe un "eliminar solicitud" en la UI).
        return;
    }
  }

  Future<void> _subirCarga(PowerSyncDatabase database, CrudEntry entrada) async {
    // El delete que llega aquí es siempre el de reconciliación descrito
    // arriba (la UI nunca borra ni edita una carga ya creada).
    if (entrada.op != UpdateType.put) return;

    final datos = entrada.opData ?? const <String, dynamic>{};
    await apiClient.dio.post('/cargas', data: {
      'solicitud_id': datos['solicitud_id'],
      'vehiculo_id': datos['vehiculo_id'],
      'litros': datos['litros'],
      'precio_por_litro': datos['precio_por_litro'],
      if (datos['km_actual'] != null) 'km_actual': datos['km_actual'],
      if (datos['km_anterior'] != null) 'km_anterior': datos['km_anterior'],
      if (datos['horas_actual'] != null) 'horas_actual': datos['horas_actual'],
      if (datos['horas_anterior'] != null) 'horas_anterior': datos['horas_anterior'],
      'creado_offline': datos['creado_offline'] == 1,
    });
    await database.execute('DELETE FROM cargas WHERE id = ?', [entrada.id]);
  }
}

/// Envoltura fina sobre [PowerSyncDatabase] para conectar/desconectar el
/// stream de sincronización en el mismo momento que la sesión REST
/// inicia/termina (ver auth_controller.dart) — PowerSync usa el mismo JWT,
/// no un login separado.
class PowerSyncClient {
  PowerSyncClient({
    required this.database,
    required TokenStorage tokenStorage,
    required ApiClient apiClient,
  }) : _connector = ApiPowerSyncConnector(tokenStorage: tokenStorage, apiClient: apiClient);

  final PowerSyncDatabase database;
  final ApiPowerSyncConnector _connector;

  /// Se llama justo después de un login exitoso (el JWT ya está guardado en
  /// TokenStorage en ese momento, así que fetchCredentials lo encuentra).
  Future<void> conectar() => database.connect(connector: _connector);

  /// Al cerrar sesión: corta el stream y borra los datos sincronizados del
  /// disco. Necesario para no dejar solicitudes/cargas/catálogos de un
  /// perfil en un dispositivo que otro usuario podría usar después.
  Future<void> desconectarYLimpiar() => database.disconnectAndClear();
}
