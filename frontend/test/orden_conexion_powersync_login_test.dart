// Prueba de regresión para el bug reportado: al iniciar sesión, la pantalla
// del rol (ej. ChoferHomePage) se monta apenas se marca `sesionProvider`
// (_SesionListenable en app_router.dart lo escucha de forma síncrona) y esa
// pantalla ya consulta el catálogo local de PowerSync (vehiculoPorIdProvider)
// contra `PowerSyncVehiculoRepository`. Si `sesionProvider` se marca ANTES de
// que termine la primera sincronización, esa consulta corre contra un
// catálogo local todavía vacío y truena con "no encontrado en el catálogo
// local" — reproducible siempre en un dispositivo nuevo o recién deslogueado.
//
// Esta prueba no necesita renderizar la UI ni una base de PowerSync real
// (ver nota sobre PowerSyncDatabase.initialize() colgándose bajo flutter_test
// en cerrar_sesion_test.dart): basta con verificar el ORDEN en que
// AuthController.iniciarSesion() llama a PowerSyncClient.conectar() versus
// cuándo deja sesionProvider con un valor no nulo.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

import 'package:gi_control_combustible/models/models.dart';
import 'package:gi_control_combustible/services/api/api_client.dart';
import 'package:gi_control_combustible/services/api/token_storage.dart';
import 'package:gi_control_combustible/services/credenciales_storage.dart';
import 'package:gi_control_combustible/services/perfil_repository.dart';
import 'package:gi_control_combustible/services/powersync/powersync_client.dart';
import 'package:gi_control_combustible/services/powersync/powersync_schema.dart';
import 'package:gi_control_combustible/state/auth_controller.dart';
import 'package:gi_control_combustible/state/providers.dart';
import 'package:gi_control_combustible/state/session_provider.dart';

const _perfilChofer = Perfil(
  id: 'perfil-chofer-prueba',
  authUserId: 'auth-chofer-prueba',
  numeroEmpleado: 'EMP-1001',
  nombreCompleto: 'Juan Pérez',
  rol: RolUsuario.chofer,
  obraId: 'obra-prueba',
  vehiculoId: 'b2000000-0000-0000-0000-000000000001',
  activo: true,
);

class _PerfilRepositoryFake implements PerfilRepository {
  @override
  Future<Perfil> iniciarSesion({
    required String numeroEmpleado,
    required String password,
  }) async =>
      _perfilChofer;

  @override
  Future<Perfil> obtenerPerfilActual() => throw UnimplementedError();
  @override
  Future<List<Perfil>> listarPorObra(String obraId) => throw UnimplementedError();
  @override
  Future<List<Perfil>> listarTodos() => throw UnimplementedError();
  @override
  Future<void> actualizarActivo(String perfilId, bool activo) => throw UnimplementedError();
  @override
  Future<Perfil> crear({
    required String nombreCompleto,
    required String numeroEmpleado,
    required String password,
    required String obraId,
    String? vehiculoId,
    String? area,
  }) =>
      throw UnimplementedError();
}

/// Registra en [eventos] cuándo arranca y termina `conectar()` — simula una
/// primera sincronización que toma un momento en resolver, para que el orden
/// incorrecto (sesión marcada antes de conectar) se note de inmediato si
/// reaparece.
class _PowerSyncClientFake extends PowerSyncClient {
  _PowerSyncClientFake(this.eventos)
      : super(
          database: PowerSyncDatabase(schema: powerSyncSchema, path: ':memory:'),
          tokenStorage: const TokenStorage(),
          apiClient: ApiClient(tokenStorage: const TokenStorage()),
        );

  final List<String> eventos;

  @override
  Future<void> conectar() async {
    eventos.add('conectar:inicio');
    // Sin Timer/Future.delayed: bajo testWidgets el reloj es falso y solo
    // avanza con tester.pump(), que esta prueba no llama mientras espera
    // iniciarSesion() — un timer real aquí cuelga la prueba para siempre.
    // Un simple `await` (sin temporizador) ya fuerza el hueco asíncrono que
    // hace falta para detectar el orden incorrecto si vuelve a aparecer.
    await Future<void>.value();
    await Future<void>.value();
    eventos.add('conectar:fin');
  }

  @override
  Future<void> desconectarYLimpiar() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iniciarSesion(): PowerSync termina de conectar antes de marcar la sesión',
    (tester) async {
      final eventos = <String>[];
      final container = ProviderContainer(
        overrides: [
          perfilRepositoryProvider.overrideWithValue(_PerfilRepositoryFake()),
          powerSyncClientProvider.overrideWithValue(_PowerSyncClientFake(eventos)),
          credencialesStorageProvider.overrideWithValue(_CredencialesStorageFakeSinIO()),
        ],
      );
      addTearDown(container.dispose);
      // baseInit() de PowerSyncDatabase corre en segundo plano al construir
      // el fake (ver nota de arriba); se descarta como "Multiple exceptions"
      // igual que en cerrar_sesion_test.dart — no forma parte de lo que esta
      // prueba verifica.
      await tester.pump();
      tester.takeException();

      container.listen(sesionProvider, (anterior, actual) {
        if (actual != null) eventos.add('sesion:marcada');
      });

      await container
          .read(authControllerProvider.notifier)
          .iniciarSesion(numeroEmpleado: 'EMP-1001', password: '1234');

      expect(eventos, ['conectar:inicio', 'conectar:fin', 'sesion:marcada']);
      expect(container.read(sesionProvider), _perfilChofer);
    },
  );
}

class _CredencialesStorageFakeSinIO extends CredencialesStorage {
  @override
  Future<({String usuario, String password})?> leer() async => null;
  @override
  Future<void> guardar({required String usuario, required String password}) async {}
  @override
  Future<void> limpiar() async {}
}
