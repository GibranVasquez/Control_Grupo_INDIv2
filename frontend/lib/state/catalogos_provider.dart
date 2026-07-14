import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/cache/catalogo_cache_service.dart';
import 'providers.dart';

const _claveCatalogoObras = 'catalogo_obras';

/// Se sobreescribe en main.dart con la instancia real (SharedPreferences.getInstance() es
/// async y debe resolverse antes de runApp; overrideWithValue es el patrón estándar de Riverpod).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider debe sobreescribirse en main.dart',
  );
});

final catalogoCacheServiceProvider = Provider<CatalogoCacheService>((ref) {
  return CatalogoCacheService(ref.watch(sharedPreferencesProvider));
});

/// Catálogo de obras: cache-first. Si hay copia vigente en disco la devuelve de inmediato
/// (sin esperar red); si no, la trae de [ObraRepository] y la guarda en caché para la
/// próxima apertura de la app.
final obrasCatalogoProvider = FutureProvider<List<Obra>>((ref) async {
  final cache = ref.watch(catalogoCacheServiceProvider);

  final enCache = cache.leer(_claveCatalogoObras);
  if (enCache != null) {
    return enCache.map(Obra.fromJson).toList();
  }

  final obras = await ref.watch(obraRepositoryProvider).listarTodas();
  await cache.guardar(
    _claveCatalogoObras,
    obras.map((o) => o.toJson()).toList(),
  );
  return obras;
});

/// Fuerza refrescar el catálogo contra la fuente real la próxima vez que se lea
/// (ej. si un admin agrega una obra nueva y no quieres esperar a que expire la caché).
Future<void> invalidarCatalogos(Ref ref) async {
  final cache = ref.read(catalogoCacheServiceProvider);
  await cache.invalidar(_claveCatalogoObras);
  ref.invalidate(obrasCatalogoProvider);
}
