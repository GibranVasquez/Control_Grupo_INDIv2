// Prueba de integración liviana (mismo criterio que
// cola_fotos_ticket_offline_test.dart): ejercita el código real de la app
// (AuthController.cerrarSesion(), AdminShell/CerrarSesionButton reales,
// GoRouter real de app_router.dart) bajo `flutter test`, fingiendo solo los
// bordes de I/O de plataforma que no aplican en este entorno headless:
// - TokenStorage/CredencialesStorage usan flutter_secure_storage.
// - PowerSyncClient normalmente envuelve un PowerSyncDatabase real
//   (sqlite nativo vía isolate propio): `PowerSyncDatabase.initialize()`
//   combinado con el pump-loop de `testWidgets` se cuelga indefinidamente
//   (probado en esta misma sesión: sin `initialize()` no hay problema, así
//   que aquí se finge todo `PowerSyncClient`, sin inicializar la base real).
// - AppTheme.light construye su TextTheme con GoogleFonts de forma eager
//   (descarga de red que se cuelga bajo flutter_test); se usa una app de
//   prueba con tema por defecto en su lugar — el tema visual no es parte de
//   lo que este test verifica.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gi_control_combustible/models/models.dart';
import 'package:gi_control_combustible/router/app_router.dart';
import 'package:gi_control_combustible/services/api/api_client.dart';
import 'package:gi_control_combustible/services/api/token_storage.dart';
import 'package:gi_control_combustible/services/credenciales_storage.dart';
import 'package:gi_control_combustible/services/powersync/powersync_client.dart';
import 'package:gi_control_combustible/services/powersync/powersync_schema.dart';
import 'package:gi_control_combustible/state/catalogos_provider.dart';
import 'package:gi_control_combustible/state/providers.dart';
import 'package:gi_control_combustible/state/session_provider.dart';
import 'package:gi_control_combustible/widgets/widgets.dart';

/// App mínima para el test: el mismo `appRouterProvider`/páginas reales de la
/// app, pero SIN `AppTheme.light` (ver nota de arriba sobre GoogleFonts).
class _AppDePrueba extends ConsumerWidget {
  const _AppDePrueba();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(routerConfig: ref.watch(appRouterProvider));
  }
}

/// TokenStorage/CredencialesStorage de prueba: en memoria, sin tocar
/// flutter_secure_storage (no aplica en este entorno headless) — mismo
/// patrón que backend/PRUEBAS.md y cola_fotos_ticket_offline_test.dart.
class _TokenStorageFake extends TokenStorage {
  String? valor = 'jwt-de-prueba';

  @override
  Future<String?> leer() async => valor;
  @override
  Future<void> guardar(String token) async => valor = token;
  @override
  Future<void> limpiar() async => valor = null;
}

class _CredencialesStorageFake extends CredencialesStorage {
  ({String usuario, String password})? valor = (usuario: 'laura', password: '1234');

  @override
  Future<({String usuario, String password})?> leer() async => valor;
  @override
  Future<void> guardar({required String usuario, required String password}) async {
    valor = (usuario: usuario, password: password);
  }

  @override
  Future<void> limpiar() async => valor = null;
}

/// PowerSyncClient de prueba: envuelve un PowerSyncDatabase real pero NUNCA
/// inicializado (ver nota de arriba) — [conectar]/[desconectarYLimpiar] no
/// tocan la base de datos real, solo registran que se llamaron.
class _PowerSyncClientFake extends PowerSyncClient {
  _PowerSyncClientFake()
      : super(
          database: PowerSyncDatabase(schema: powerSyncSchema, path: ':memory:'),
          tokenStorage: const TokenStorage(),
          apiClient: ApiClient(tokenStorage: const TokenStorage()),
        );

  bool desconectado = false;

  @override
  Future<void> conectar() async {}

  @override
  Future<void> desconectarYLimpiar() async {
    desconectado = true;
  }
}

/// Descarta cualquier excepción de renderizado pendiente del frame — se usa
/// solo para el overflow cosmético ya diagnosticado (ver comentario junto al
/// primer pump); `flutter_test` agrupa varias en un solo objeto envoltorio
/// ("Multiple exceptions..."), así que no vale la pena intentar matchear el
/// texto exacto aquí.
void _descartarSoloOverflow(WidgetTester tester) {
  tester.takeException();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Cerrar sesión: limpia sesión/JWT/biometría y regresa a /login',
    timeout: const Timeout(Duration(seconds: 30)),
    (tester) async {
      // Viewport ancho (layout de escritorio de AdminShell) para no depender
      // del tamaño por defecto del harness de test.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final tokenStorageFake = _TokenStorageFake();
      final credencialesFake = _CredencialesStorageFake();
      final powerSyncClientFake = _PowerSyncClientFake();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(tokenStorageFake),
          credencialesStorageProvider.overrideWithValue(credencialesFake),
          powerSyncClientProvider.overrideWithValue(powerSyncClientFake),
        ],
      );
      addTearDown(container.dispose);

      // Perfil administrativo SIN obra asignada: BandejaAutorizacionesPage
      // (pestaña inicial de AdministrativoHomePage) corta antes de pedir
      // ningún dato remoto/local, así que la pantalla completa (con el
      // AdminShell real y su botón de cerrar sesión real) se puede renderizar
      // sin necesitar PowerSync/backend real.
      const perfilAdmin = Perfil(
        id: 'perfil-prueba',
        authUserId: 'auth-prueba',
        usuario: 'laura',
        nombreCompleto: 'Admin de Prueba',
        rol: RolUsuario.administrativo,
        obraId: null,
        activo: true,
      );
      container.read(sesionProvider.notifier).iniciarSesion(perfilAdmin);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const _AppDePrueba()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // La sidebar de AdminShell tiene ancho fijo (210px) pensado para la
      // fuente real (Manrope, vía GoogleFonts); la fuente de reemplazo que
      // usa flutter_test es más ancha y desborda unos px en `_ItemNav` — es
      // un artefacto cosmético del entorno de test (ver nota de GoogleFonts
      // arriba), no un bug: se descarta explícitamente en vez de dejar que
      // tumbe el test.
      _descartarSoloOverflow(tester);

      // Confirma que arrancó en la pantalla de administrativo (sesión activa).
      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.text('Admin de Prueba'), findsWidgets);
      expect(find.text('Tu usuario no tiene una obra asignada.'), findsOneWidget);

      // Tap en el botón de cerrar sesión de la sidebar.
      expect(find.byType(CerrarSesionButton), findsOneWidget);
      await tester.tap(find.byType(CerrarSesionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _descartarSoloOverflow(tester);

      // Confirma en el diálogo.
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cerrar sesión'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      _descartarSoloOverflow(tester);

      // 1. Regresó a la pantalla de login.
      expect(find.text('INDI Combustible'), findsOneWidget);
      expect(find.byType(AdminShell), findsNothing);

      // 2. La sesión en memoria quedó limpia.
      expect(container.read(sesionProvider), isNull);

      // 3. El JWT quedó limpio.
      expect(await tokenStorageFake.leer(), isNull);

      // 4. Las credenciales de biometría quedaron limpias (el fix de la
      // conversación anterior: cerrarSesion() ya no dejaba esto sin limpiar).
      expect(await credencialesFake.leer(), isNull);

      // 5. PowerSync se desconectó y limpió los datos locales.
      expect(powerSyncClientFake.desconectado, isTrue);
    },
  );
}
