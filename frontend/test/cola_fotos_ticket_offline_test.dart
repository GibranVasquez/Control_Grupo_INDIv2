// Prueba de escenario real (ver backend/PRUEBAS.md para el precedente y las
// restricciones del entorno): este contenedor no tiene emulador/Chrome, así
// que no se puede conducir la UI real. En su lugar se ejercita el código de
// producción real —PowerSyncCargaRepository, ColaFotosTicketService,
// ApiPowerSyncConnector, ApiClient/Dio real— contra el backend real
// (apuntando a Railway vía backend/.env, debe estar corriendo en
// localhost:4000 antes de correr este test) desde el harness de
// `flutter test` (no `dart run`: varios plugins necesitan `dart:ui`).
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gi_control_combustible/models/models.dart';
import 'package:gi_control_combustible/services/api/api_client.dart';
import 'package:gi_control_combustible/services/api/token_storage.dart';
import 'package:gi_control_combustible/services/cola_fotos_ticket_service.dart';
import 'package:gi_control_combustible/services/powersync/powersync_carga_repository.dart';
import 'package:gi_control_combustible/services/powersync/powersync_client.dart';
import 'package:gi_control_combustible/services/powersync/powersync_schema.dart';

const _baseUrlReal = 'http://localhost:4000';
// Puerto local sin nada escuchando: usarlo como baseUrl simula "sin
// conexión"/"backend caído" con un error de Dio real (connection refused),
// sin depender de apagar servicios de verdad durante el test.
const _baseUrlSinConexion = 'http://127.0.0.1:9';

const _vehiculoFordF150Id = 'b2000000-0000-0000-0000-000000000001';

/// TokenStorage de prueba: JWT fijo en memoria, sin tocar
/// flutter_secure_storage (no aplica en este entorno headless) — mismo
/// patrón que las pruebas de backend/PRUEBAS.md.
class _TokenFijo extends TokenStorage {
  const _TokenFijo(this._token);
  final String _token;

  @override
  Future<String?> leer() async => _token;
  @override
  Future<void> guardar(String token) async {}
  @override
  Future<void> limpiar() async {}
}

Future<String> _login(Dio dio, String numeroEmpleado) async {
  final respuesta = await dio.post<Map<String, dynamic>>(
    '/auth/login',
    data: {'numero_empleado': numeroEmpleado, 'password': '1234'},
  );
  return respuesta.data!['token'] as String;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test intercepta dart:io HttpClient y responde 400 a todo por
  // defecto (para que los widget tests no dependan de red real). Este test
  // necesita hablar con el backend real a propósito, así que se desactiva.
  HttpOverrides.global = null;

  test(
    'ticket sin conexión: la carga se guarda igual y la foto se sube sola al reconectar',
    () async {
      final dioLogin = Dio(BaseOptions(baseUrl: _baseUrlReal));

      // 0. Arma un escenario 100% real contra Railway: login chofer/admin,
      // solicitud creada y autorizada de lleno (sin necesitar comentario).
      final tokenChofer = await _login(dioLogin, 'EMP-1001');
      final tokenAdmin = await _login(dioLogin, 'EMP-2001');

      final dioChofer = Dio(BaseOptions(baseUrl: _baseUrlReal))
        ..options.headers['Authorization'] = 'Bearer $tokenChofer';
      final dioAdmin = Dio(BaseOptions(baseUrl: _baseUrlReal))
        ..options.headers['Authorization'] = 'Bearer $tokenAdmin';

      final solicitudResp = await dioChofer.post<Map<String, dynamic>>(
        '/solicitudes-autorizacion',
        data: {'vehiculo_id': _vehiculoFordF150Id, 'litros_solicitados': 12},
      );
      final solicitudId = solicitudResp.data!['solicitud']['id'] as String;

      await dioAdmin.put<Map<String, dynamic>>(
        '/solicitudes-autorizacion/$solicitudId/resolver',
        data: {'estado': 'autorizado', 'litros_autorizados': 12},
      );

      // 1. Directorio temporal propio del test, y mock de path_provider (ver
      // ColaFotosTicketService.agregar, que usa getApplicationSupportDirectory)
      // — flutter test no tiene un canal de plataforma real para esto.
      final tempDir = await Directory.systemTemp.createTemp('cola_fotos_test_');
      const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            if (call.method == 'getApplicationSupportDirectory') return tempDir.path;
            return null;
          });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cola = ColaFotosTicketService(prefs);

      // 2. Base local de PowerSync (temporal), igual que abrirBaseDeDatosPowerSync()
      // pero apuntando a un archivo desechable del test.
      final db = PowerSyncDatabase(schema: powerSyncSchema, path: '${tempDir.path}/test.db');
      await db.initialize();

      // 3. ApiClient "sin conexión": puerto local donde no hay nada escuchando.
      final apiClientSinConexion = ApiClient(
        tokenStorage: _TokenFijo(tokenChofer),
        baseUrl: _baseUrlSinConexion,
      );
      final cargaRepoSinConexion = PowerSyncCargaRepository(
        database: db,
        apiClient: apiClientSinConexion,
      );

      // 4. El chofer registra la carga con el backend "caído": crear() es
      // 100% local (offline-first), así que debe tener éxito igual.
      final cargaId = await cargaRepoSinConexion.crear(
        Carga(
          id: '',
          solicitudId: solicitudId,
          choferId: '', // no se usa: crear() no lee este campo del modelo, solo hace el INSERT local.
          vehiculoId: _vehiculoFordF150Id,
          obraId: 'a1000000-0000-0000-0000-000000000001',
          litros: 12,
          precioPorLitro: 24.5,
          montoTotal: 12 * 24.5,
          kmActual: 50100,
          kmAnterior: 50000,
          fechaCarga: DateTime.now(),
          creadoOffline: false,
        ),
      );

      // Confirma: "la carga se guarda igual" (fila real en el sqlite local).
      final filaLocal = await db.getOptional('SELECT * FROM cargas WHERE id = ?', [cargaId]);
      expect(filaLocal, isNotNull, reason: 'la carga debe quedar guardada localmente aunque el backend esté caído');

      // 5. El chofer toma la foto del ticket (archivo de prueba) e intenta
      // subirla de inmediato: debe fallar porque no hay conexión.
      final fotoOriginal = File('${tempDir.path}/ticket_original.jpg')
        ..writeAsBytesSync(utf8.encode('contenido-de-prueba-del-ticket'));

      await expectLater(
        cargaRepoSinConexion.subirFotoTicket(cargaId, fotoOriginal.path),
        throwsA(isA<DioException>()),
        reason: 'sin conexión, la subida del ticket debe fallar con un error de red',
      );

      // 6. Como falló, se encola (mismo código que comprobar_carga_page.dart
      // ejecuta tras agotar sus reintentos cortos).
      await cola.agregar(cargaId: cargaId, rutaLocal: fotoOriginal.path);
      final pendientesTrasFallo = cola.listar();
      expect(pendientesTrasFallo, hasLength(1));
      expect(pendientesTrasFallo.single.cargaId, cargaId);
      // La copia persistente debe existir en disco (sobrevive a que se borre
      // el archivo temporal original de image_picker).
      expect(File(pendientesTrasFallo.single.rutaLocal).existsSync(), isTrue);

      // 7. "Se restaura la conexión": ApiClient real contra el backend real.
      final apiClientOnline = ApiClient(tokenStorage: _TokenFijo(tokenChofer), baseUrl: _baseUrlReal);
      final cargaRepoOnline = PowerSyncCargaRepository(database: db, apiClient: apiClientOnline);

      // La fila de la carga solo vive en el sqlite local todavía (nunca se
      // subió, porque el backend estaba caído): hace falta que el conector
      // real de PowerSync suba la cola de escritura pendiente, exactamente
      // como ocurre en producción apenas el SDK detecta conexión — mismo
      // mecanismo ya verificado en backend/PRUEBAS.md (pruebas 2 y 3).
      final conectorOnline = ApiPowerSyncConnector(
        tokenStorage: _TokenFijo(tokenChofer),
        apiClient: apiClientOnline,
      );
      await conectorOnline.uploadData(db);

      // Confirma que la carga ya existe en el backend real con el mismo id.
      final cargaEnBackend = await dioChofer.get<Map<String, dynamic>>('/cargas', queryParameters: {});
      final idsBackend = (cargaEnBackend.data!['cargas'] as List<dynamic>)
          .map((c) => c['id'] as String)
          .toList();
      expect(idsBackend, contains(cargaId), reason: 'la carga debe haber llegado al backend real tras "reconectar"');

      // 8. Vaciado de la cola: mismo cuerpo que colaFotosTicketWatcherProvider
      // ejecuta automáticamente al detectar conexión recuperada.
      for (final pendiente in cola.listar()) {
        var subida = false;
        for (var intento = 0; intento < 3 && !subida; intento++) {
          try {
            await cargaRepoOnline.subirFotoTicket(pendiente.cargaId, pendiente.rutaLocal);
            subida = true;
          } catch (_) {
            if (intento < 2) await Future.delayed(Duration(milliseconds: 500 * (intento + 1)));
          }
        }
        if (subida) await cola.quitar(pendiente.cargaId);
      }

      // 9. Sin intervención manual del usuario: la cola quedó vacía...
      expect(cola.listar(), isEmpty, reason: 'la cola debe vaciarse sola tras la reconexión, sin acción del usuario');
      // ...y el archivo local de la copia persistente se borró al confirmarse la subida.
      expect(File(pendientesTrasFallo.single.rutaLocal).existsSync(), isFalse);

      // ...y el backend real ya tiene la URL del ticket (la foto sí se subió).
      final cargasChofer = await dioChofer.get<Map<String, dynamic>>('/cargas');
      final cargaActualizada = (cargasChofer.data!['cargas'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == cargaId);
      expect(cargaActualizada['foto_ticket_url'], isNotNull);

      await db.disconnectAndClear();
      await tempDir.delete(recursive: true);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
