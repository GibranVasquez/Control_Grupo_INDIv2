import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'router/app_router.dart';
import 'services/powersync/powersync_client.dart';
import 'state/catalogos_provider.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'widgets/banner_sin_conexion.dart';

/// Configurable con `--dart-define=SENTRY_DSN=https://...`, mismo patrón que
/// API_URL/POWERSYNC_URL (ver api_client.dart/powersync_client.dart). Sin
/// DSN, SentryFlutter.init() deja el SDK deshabilitado (no manda nada, sin
/// costo de rendimiento) — seguro de dejar así hasta que exista una cuenta.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);
  final sharedPreferences = await SharedPreferences.getInstance();
  // Abrir el archivo SQLite de PowerSync requiere I/O async (path_provider)
  // antes de runApp, igual que SharedPreferences.getInstance() arriba.
  final powerSyncDatabase = await abrirBaseDeDatosPowerSync();

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = const bool.fromEnvironment('dart.vm.product')
          ? 'production'
          : 'development';
    },
    appRunner: () => runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          powerSyncDatabaseProvider.overrideWithValue(powerSyncDatabase),
        ],
        child: const MainApp(),
      ),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivo el vaciado automático de la cola de fotos de ticket
    // pendientes durante toda la vida de la app (ver providers.dart).
    ref.watch(colaFotosTicketWatcherProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'INDI Combustible',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => Column(
        children: [
          const BannerSinConexion(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
