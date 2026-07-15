# Build de producción

Regla general: siempre `--release`, nunca `--debug`/`--profile` para el
entregable final — Flutter ya minifica y tree-shakea en release por defecto;
lo que agregan los flags de abajo es **quitar símbolos de depuración y mapas
de código fuente** para no exponer el código Dart original.

Variables de entorno reales de esta app (ver
`lib/services/api/api_client.dart` y `lib/services/powersync/powersync_client.dart`):

- `API_URL`: URL base de la API REST propia (backend/src/). Por defecto
  `http://localhost:4000` — **hay que pasarla explícitamente en cualquier
  build que no sea para correr localmente**, o la app apuntará a localhost en
  el dispositivo del cliente y no funcionará.
- `POWERSYNC_URL`: URL del servicio PowerSync self-hosted. Por defecto
  `http://localhost:8080` — mismo criterio que `API_URL`.

Este proyecto ya no usa Supabase (migrado a backend propio + PowerSync
self-hosted, ver `backend/DECISIONES.md`); no hay `SUPABASE_URL`/
`SUPABASE_ANON_KEY` que definir.

## Web

```
flutter build web --release --no-source-maps \
  --dart-define=API_URL=https://... --dart-define=POWERSYNC_URL=https://...
```

- `--release` compila con dart2js en modo optimizado (minifica, tree-shake de
  íconos y código muerto) — es el default de `flutter build web`, no hace
  falta el flag, pero se deja explícito por claridad.
- `--no-source-maps` es el default real (Flutter no genera `.js.map` salvo que
  pidas `--source-maps` a propósito) — nunca actives ese flag en el build que
  se publica.
- Salida: `build/web/`. El `main.dart.js` ya sale minificado/ofuscado por
  dart2js; no hay paso extra de "minificar" separado como en un bundler JS.
- Nota: esta app usa `path_provider` (base de datos local de PowerSync) con
  métodos que no tienen implementación en web (`getApplicationSupportDirectory`
  truena con `MissingPluginException` al arrancar en Chrome) — el target web
  no está soportado hoy. Usar Android/iOS/Windows/macOS/Linux.

## Android

```
flutter build appbundle --release ^
  --obfuscate ^
  --split-debug-info=build/debug-info/android ^
  --dart-define=API_URL=https://... --dart-define=POWERSYNC_URL=https://...
```

- `--obfuscate` renombra símbolos Dart (clases, métodos) a identificadores
  cortos — así protege la lógica de negocio si alguien decompila el APK/AAB.
- `--split-debug-info=<dir>` saca los símbolos de depuración a archivos
  separados (necesarios solo para poder leer un stack trace de un crash en
  producción) — **no se suben a la tienda ni al repo**, se guardan en un
  lugar seguro del equipo para simbolizar crashes reportados.

## iOS

```
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info/ios \
  --dart-define=API_URL=https://... --dart-define=POWERSYNC_URL=https://...
```

## Windows

```
flutter build windows --release --obfuscate --split-debug-info=build/debug-info/windows ^
  --dart-define=API_URL=https://... --dart-define=POWERSYNC_URL=https://...
```

El build de escritorio no tiene "source maps" (es código nativo compilado por
MSVC/CMake, no JS) — `--obfuscate` aquí es lo que protege símbolos Dart contra
decompilación con herramientas de reversing.

## Notas

- Nunca commitear `build/debug-info/` — ya está cubierto por el
  `.gitignore` de Flutter (`build/`), pero si guardas esos symbols en otro
  lado (recomendado: artefacto de CI), verifícalo explícitamente.
- `API_URL`/`POWERSYNC_URL` se pasan por `--dart-define`, nunca hardcodeados
  en el código — en CI van como variables/secrets del pipeline.
- Íconos de app y splash screen: siguen siendo los genéricos de Flutter (ver
  `web/icons/*.png`, sin `flutter_launcher_icons`/`flutter_native_splash`
  configurados) — falta el logo real del cliente para generarlos.
