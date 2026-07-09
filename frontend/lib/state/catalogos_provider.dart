import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dev/datos_demo.dart';
import '../models/models.dart';
import '../services/cache/catalogo_cache_service.dart';

const _claveCatalogoObras = 'catalogo_obras';
const _claveCatalogoIngenieros = 'catalogo_ingenieros';

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
/// (sin esperar red); si no, "trae" de DatosDemo (aquí iría la llamada a ObraRepository
/// cuando exista) y la guarda en caché para la próxima apertura de la app.
final obrasCatalogoProvider = FutureProvider<List<Obra>>((ref) async {
  final cache = ref.watch(catalogoCacheServiceProvider);

  final enCache = cache.leer(_claveCatalogoObras);
  if (enCache != null) {
    return enCache.map(Obra.fromJson).toList();
  }

  // TODO: reemplazar por ObraRepository.listar() cuando el repositorio esté conectado a Supabase.
  final obras = DatosDemo.obras;
  await cache.guardar(
    _claveCatalogoObras,
    obras.map((o) => o.toJson()).toList(),
  );
  return obras;
});

/// Catálogo de ingenieros elegibles en el registro (`register_page.dart`). Mismo patrón
/// cache-first que [obrasCatalogoProvider].
final ingenierosCatalogoProvider = FutureProvider<List<Perfil>>((ref) async {
  final cache = ref.watch(catalogoCacheServiceProvider);

  final enCache = cache.leer(_claveCatalogoIngenieros);
  if (enCache != null) {
    return enCache.map(Perfil.fromJson).toList();
  }

  // TODO: reemplazar por PerfilRepository.listarIngenieros() cuando esté conectado a Supabase.
  final ingenieros = DatosDemo.ingenierosDemo;
  await cache.guardar(
    _claveCatalogoIngenieros,
    ingenieros.map((i) => i.toJson()).toList(),
  );
  return ingenieros;
});

/// Fuerza refrescar ambos catálogos contra la fuente real la próxima vez que se lean
/// (ej. si un admin agrega una obra nueva y no quieres esperar a que expire la caché).
Future<void> invalidarCatalogos(Ref ref) async {
  final cache = ref.read(catalogoCacheServiceProvider);
  await cache.invalidar(_claveCatalogoObras);
  await cache.invalidar(_claveCatalogoIngenieros);
  ref.invalidate(obrasCatalogoProvider);
  ref.invalidate(ingenierosCatalogoProvider);
}
