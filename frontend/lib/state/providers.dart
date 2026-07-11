import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';

import '../models/models.dart';
import '../services/api/api_client.dart';
import '../services/api/api_perfil_repository.dart';
import '../services/api/api_reportes_repository.dart';
import '../services/api/api_semana_operativa_repository.dart';
import '../services/api/token_storage.dart';
import '../services/biometria_service.dart';
import '../services/credenciales_storage.dart';
import '../services/powersync/powersync_carga_repository.dart';
import '../services/powersync/powersync_client.dart';
import '../services/powersync/powersync_obra_repository.dart';
import '../services/powersync/powersync_precio_combustible_repository.dart';
import '../services/powersync/powersync_solicitud_autorizacion_repository.dart';
import '../services/powersync/powersync_vehiculo_repository.dart';
import '../services/services.dart';
import 'session_provider.dart';

/// Se sobreescribe en main.dart con la base ya abierta (abrir el archivo
/// SQLite requiere I/O async de path_provider antes de runApp — mismo patrón
/// que sharedPreferencesProvider en catalogos_provider.dart).
final powerSyncDatabaseProvider = Provider<PowerSyncDatabase>((ref) {
  throw UnimplementedError(
    'powerSyncDatabaseProvider debe sobreescribirse en main.dart',
  );
});

final tokenStorageProvider = Provider<TokenStorage>((ref) => const TokenStorage());

/// Ajeno a Supabase: guarda usuario/password en claro (ver credenciales_storage.dart)
/// para poder repetir iniciarSesion() completo tras un desbloqueo biométrico exitoso,
/// tanto para el flujo demo (usuariosRegistradosProvider) como para el real contra la
/// API. No se reemplaza por TokenStorage porque el flujo demo nunca emite un JWT.
final credencialesStorageProvider = Provider<CredencialesStorage>((ref) => const CredencialesStorage());

/// Ante un 401 de la API, se limpia la sesión en memoria: app_router.dart ya
/// redirige solo a /login cuando sesionProvider queda en null (ver
/// _redirigirSegunSesion), así que no hace falta tocar el router desde aquí.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    onUnauthorized: () => ref.read(sesionProvider.notifier).cerrarSesion(),
  );
});

/// Mismo criterio que apiClientProvider: si el conector detecta que el JWT ya
/// venció (ver ApiPowerSyncConnector.fetchCredentials), se limpia la sesión
/// en memoria de la misma forma, para que app_router.dart regrese a /login.
final powerSyncClientProvider = Provider<PowerSyncClient>((ref) {
  return PowerSyncClient(
    database: ref.watch(powerSyncDatabaseProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    apiClient: ref.watch(apiClientProvider),
    onUnauthorized: () => ref.read(sesionProvider.notifier).cerrarSesion(),
  );
});

final perfilRepositoryProvider = Provider<PerfilRepository>((ref) {
  return ApiPerfilRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    powerSyncDatabase: ref.watch(powerSyncDatabaseProvider),
  );
});

final vehiculoRepositoryProvider = Provider<VehiculoRepository>((ref) {
  return PowerSyncVehiculoRepository(
    database: ref.watch(powerSyncDatabaseProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

final obraRepositoryProvider = Provider<ObraRepository>((ref) {
  return PowerSyncObraRepository(database: ref.watch(powerSyncDatabaseProvider));
});

final precioCombustibleRepositoryProvider = Provider<PrecioCombustibleRepository>((ref) {
  return PowerSyncPrecioCombustibleRepository(
    database: ref.watch(powerSyncDatabaseProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

final solicitudAutorizacionRepositoryProvider = Provider<SolicitudAutorizacionRepository>((ref) {
  return PowerSyncSolicitudAutorizacionRepository(database: ref.watch(powerSyncDatabaseProvider));
});

final cargaRepositoryProvider = Provider<CargaRepository>((ref) {
  return PowerSyncCargaRepository(
    database: ref.watch(powerSyncDatabaseProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

final semanaOperativaRepositoryProvider = Provider<SemanaOperativaRepository>((ref) {
  return ApiSemanaOperativaRepository(apiClient: ref.watch(apiClientProvider));
});

final reportesRepositoryProvider = Provider<ReportesRepository>((ref) {
  return ApiReportesRepository(apiClient: ref.watch(apiClientProvider));
});

final biometriaServiceProvider = Provider<BiometriaService>((ref) => BiometriaService());

// ---------------------------------------------------------------------
// Providers de lectura por parámetro (family): envuelven un método de
// repositorio en un FutureProvider cacheado por argumento, para que las
// pantallas puedan `ref.watch(...)` en vez de manejar Futures a mano.
// Tras una escritura (crear/resolver/actualizar), quien la dispare debe
// invalidar el provider correspondiente para refrescar la lectura — mismo
// patrón que invalidarCatalogos() en catalogos_provider.dart.
// ---------------------------------------------------------------------

final vehiculoPorIdProvider = FutureProvider.family<Vehiculo, String>((ref, vehiculoId) {
  return ref.watch(vehiculoRepositoryProvider).obtenerPorId(vehiculoId);
});

final vehiculosPorObraProvider = FutureProvider.family<List<Vehiculo>, String>((ref, obraId) {
  return ref.watch(vehiculoRepositoryProvider).listarPorObra(obraId);
});

final obraPorIdProvider = FutureProvider.family<Obra, String>((ref, obraId) {
  return ref.watch(obraRepositoryProvider).obtenerPorId(obraId);
});

final perfilesPorObraProvider = FutureProvider.family<List<Perfil>, String>((ref, obraId) {
  return ref.watch(perfilRepositoryProvider).listarPorObra(obraId);
});

final precioVigenteProvider = FutureProvider.family<PrecioCombustible, TipoCombustible>((ref, tipo) {
  return ref.watch(precioCombustibleRepositoryProvider).obtenerVigente(tipo);
});

final solicitudesPendientesObraProvider = FutureProvider.family<List<SolicitudAutorizacion>, String>((
  ref,
  obraId,
) {
  return ref.watch(solicitudAutorizacionRepositoryProvider).listarPendientesPorObra(obraId);
});

final solicitudesPorChoferProvider = FutureProvider.family<List<SolicitudAutorizacion>, String>((
  ref,
  choferId,
) {
  return ref.watch(solicitudAutorizacionRepositoryProvider).listarPorChofer(choferId);
});

final ultimaCargaPorVehiculoProvider = FutureProvider.family<Carga?, String>((ref, vehiculoId) {
  return ref.watch(cargaRepositoryProvider).obtenerUltimaPorVehiculo(vehiculoId);
});

final consumoSemanalVehiculoProvider = FutureProvider.family<VistaConsumoVehiculoSemanal, String>((
  ref,
  vehiculoId,
) {
  return ref.watch(reportesRepositoryProvider).consumoSemanalDeVehiculo(vehiculoId);
});

final fondoSemanalObraProvider = FutureProvider.family<List<FondoSemanal>, String>((ref, obraId) {
  return ref.watch(reportesRepositoryProvider).fondoSemanalPorObra(obraId: obraId);
});

final concentradoCargasObraProvider = FutureProvider.family<List<VistaConcentradoCargas>, String>((
  ref,
  obraId,
) {
  return ref.watch(reportesRepositoryProvider).concentradoCargas(obraId: obraId);
});

final resumenFinancieroSemanalProvider = FutureProvider.family<List<VistaResumenFinancieroSemanal>, String>((
  ref,
  obraId,
) {
  return ref.watch(reportesRepositoryProvider).resumenFinancieroSemanal(obraId: obraId);
});

/// true solo si la plataforma es móvil, el dispositivo soporta biometría y ya hay una sesión
/// previa guardada (es decir, el usuario ya se registró/inició sesión antes en este dispositivo).
final puedeUsarBiometriaProvider = FutureProvider<bool>((ref) async {
  final servicio = ref.watch(biometriaServiceProvider);
  if (!servicio.soportadaEnPlataforma) return false;
  final credenciales = await ref.watch(credencialesStorageProvider).leer();
  if (credenciales == null) return false;
  return servicio.disponible();
});
