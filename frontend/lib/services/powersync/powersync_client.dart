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

/// Margen de seguridad antes de la expiración real del JWT: si a un token le
/// queda menos que esto (o ya expiró), se trata igual que si ya hubiera
/// vencido — no tiene sentido ofrecérselo a PowerSync para una conexión que
/// de todos modos va a quedar sin servir datos casi de inmediato.
const _margenExpiracionToken = Duration(seconds: 10);

/// Conector que traduce entre PowerSync (SQLite local) y nuestra API REST.
///
/// - [fetchCredentials]: PowerSync no tiene login propio; reutiliza el mismo
///   JWT que ya emitió `POST /auth/login` (ver [TokenStorage]) sin pedir una
///   autenticación aparte (backend/powersync/POWERSYNC.md, sección 2). Antes
///   de entregar el token, se revisa su propio claim `exp`: si ya venció (o
///   está a punto de hacerlo), se limpia la sesión y se notifica a
///   [onUnauthorized] — igual que ante un 401 de la API REST (ver
///   api_client.dart) — en vez de dejar que PowerSync siga "conectado" sin
///   avisar a nadie.
///
///   Esto NO se basa en leer `token_expires_in` del cuerpo de
///   `/sync/stream`: ese campo es parte del protocolo interno entre el
///   servicio de PowerSync y su cliente de sync nativo, y no se expone a
///   través de la API pública de `PowerSyncBackendConnector` (los únicos
///   hooks disponibles son `fetchCredentials`/`uploadData`). Además, un JWT
///   bien formado pero vencido no produce un 401 en `/sync/stream` — el
///   servicio responde 200 con `{"token_expires_in": 0}` y sin datos (ver
///   backend/PRUEBAS.md, prueba 4). Por eso la detección se hace aquí,
///   decodificando el propio `exp` del JWT con
///   `PowerSyncCredentials.getExpiryDate` (utilidad que ya trae el paquete
///   `powersync` para este propósito) antes de ofrecérselo al SDK.
/// - [uploadData]: traduce cada entrada de la cola de escritura local a la
///   llamada REST equivalente. Solo `solicitudes_autorizacion` (insertar,
///   resolver) y `cargas` (insertar) generan escrituras locales; el resto de
///   las tablas del esquema son catálogos de solo lectura (ver
///   powersync_schema.dart) y nunca deberían aparecer aquí.
class ApiPowerSyncConnector extends PowerSyncBackendConnector {
  ApiPowerSyncConnector({
    required this.tokenStorage,
    required this.apiClient,
    this.onUnauthorized,
  });

  final TokenStorage tokenStorage;
  final ApiClient apiClient;

  /// Mismo callback que [OnUnauthorized] en api_client.dart: quien arme este
  /// conector (ver [PowerSyncClient]/providers.dart) decide qué hacer,
  /// normalmente limpiar la sesión en memoria para que app_router.dart
  /// redirija a /login. No hay todavía un flujo de refresh de JWT en el
  /// backend (JWT_EXPIRES_IN es fijo, ver auth.service.ts): mientras no
  /// exista, este es el único camino disponible ante un token vencido.
  final OnUnauthorized? onUnauthorized;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final token = await tokenStorage.leer();
    if (token == null) return null;

    final expiraEn = PowerSyncCredentials.getExpiryDate(token);
    final estaPorVencerOVencido =
        expiraEn != null && !expiraEn.isAfter(DateTime.now().add(_margenExpiracionToken));
    if (estaPorVencerOVencido) {
      await tokenStorage.limpiar();
      onUnauthorized?.call();
      return null;
    }

    return PowerSyncCredentials(endpoint: powerSyncUrl, token: token);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final lote = await database.getCrudBatch();
    if (lote == null) return;

    for (final entrada in lote.crud) {
      await _subirEntrada(entrada);
    }
    await lote.complete();
  }

  Future<void> _subirEntrada(CrudEntry entrada) {
    switch (entrada.table) {
      case 'solicitudes_autorizacion':
        return _subirSolicitud(entrada);
      case 'cargas':
        return _subirCarga(entrada);
      default:
        // vehiculos/obras/perfiles/precios_combustible son catálogos de solo
        // lectura para el cliente (ver powersync_schema.dart): ningún
        // repositorio debería escribir en ellos localmente. Si de todos
        // modos aparece una entrada, se descarta para no bloquear la cola
        // de subida indefinidamente con un op que nunca vamos a poder subir.
        return Future.value();
    }
  }

  /// El id que genera PowerSyncSolicitudAutorizacionRepository/
  /// PowerSyncCargaRepository al insertar offline (uuid v4) se manda tal
  /// cual en el body como `id`; el backend (solicitudAutorizacion.service.ts
  /// / carga.service.ts) lo valida y lo usa como id real en vez de generar
  /// uno nuevo. La fila local y la fila del servidor son entonces siempre el
  /// mismo registro — ya no hace falta borrar la fila optimista ni esperar a
  /// que la real llegue por sync (como antes de que el backend aceptara id).
  Future<void> _subirSolicitud(CrudEntry entrada) async {
    switch (entrada.op) {
      case UpdateType.put:
        final datos = entrada.opData ?? const <String, dynamic>{};
        await apiClient.dio.post('/solicitudes-autorizacion', data: {
          'id': entrada.id,
          'vehiculo_id': datos['vehiculo_id'],
          'litros_solicitados': datos['litros_solicitados'],
          if (datos['comentario'] != null) 'comentario': datos['comentario'],
          if (datos['actividad'] != null) 'actividad': datos['actividad'],
          if (datos['responsable'] != null) 'responsable': datos['responsable'],
          'creado_offline': datos['creado_offline'] == 1,
        });
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
        // La UI nunca borra solicitudes; no hay ningún flujo que genere esto.
        return;
    }
  }

  Future<void> _subirCarga(CrudEntry entrada) async {
    if (entrada.op != UpdateType.put) return; // la UI nunca edita/borra una carga ya creada.

    final datos = entrada.opData ?? const <String, dynamic>{};
    // precio_por_litro/km_anterior/horas_anterior deliberadamente NO se
    // mandan: carga.service.ts los ignora si llegan y siempre los calcula él
    // mismo (precio vigente por tipo de combustible del vehículo, km/horas
    // anterior de la última carga real) — mandarlos aquí solo sería ruido
    // (el valor local es apenas una previsualización, ver
    // carga_repository.dart#obtenerUltimaPorVehiculo).
    await apiClient.dio.post('/cargas', data: {
      'id': entrada.id,
      'solicitud_id': datos['solicitud_id'],
      'vehiculo_id': datos['vehiculo_id'],
      'litros': datos['litros'],
      if (datos['km_actual'] != null) 'km_actual': datos['km_actual'],
      if (datos['horas_actual'] != null) 'horas_actual': datos['horas_actual'],
      'creado_offline': datos['creado_offline'] == 1,
    });
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
    OnUnauthorized? onUnauthorized,
  }) : _connector = ApiPowerSyncConnector(
          tokenStorage: tokenStorage,
          apiClient: apiClient,
          onUnauthorized: onUnauthorized,
        );

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
