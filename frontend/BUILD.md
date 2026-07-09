# Build de producción

Regla general: siempre `--release`, nunca `--debug`/`--profile` para el
entregable final — Flutter ya minifica y tree-shakea en release por defecto;
lo que agregan los flags de abajo es **quitar símbolos de depuración y mapas
de código fuente** para no exponer el código Dart original.

## Web

```
flutter build web --release --no-source-maps --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

- `--release` compila con dart2js en modo optimizado (minifica, tree-shake de
  íconos y código muerto) — es el default de `flutter build web`, no hace
  falta el flag, pero se deja explícito por claridad.
- `--no-source-maps` es el default real (Flutter no genera `.js.map` salvo que
  pidas `--source-maps` a propósito) — nunca actives ese flag en el build que
  se publica.
- Salida: `build/web/`. El `main.dart.js` ya sale minificado/ofuscado por
  dart2js; no hay paso extra de "minificar" separado como en un bundler JS.

## Android

```
flutter build appbundle --release ^
  --obfuscate ^
  --split-debug-info=build/debug-info/android ^
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

- `--obfuscate` renombra símbolos Dart (clases, métodos) a identificadores
  cortos — así protege la lógica de negocio si alguien decompila el APK/AAB.
- `--split-debug-info=<dir>` saca los símbolos de depuración a archivos
  separados (necesarios solo para poder leer un stack trace de un crash en
  producción) — **no se suben a la tienda ni al repo**, se guardan en un
  lugar seguro del equipo para simbolizar crashes reportados.

## iOS

```
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info/ios
```

## Windows

```
flutter build windows --release --obfuscate --split-debug-info=build/debug-info/windows
```

El build de escritorio no tiene "source maps" (es código nativo compilado por
MSVC/CMake, no JS) — `--obfuscate` aquí es lo que protege símbolos Dart contra
decompilación con herramientas de reversing.

## Notas

- Nunca commitear `build/debug-info/` — ya está cubierto por el
  `.gitignore` de Flutter (`build/`), pero si guardas esos symbols en otro
  lado (recomendado: artefacto de CI), verifícalo explícitamente.
- Las credenciales de Supabase se pasan por `--dart-define`, nunca
  hardcodeadas en `main.dart` (ver el TODO ahí) — en CI van como secrets del
  pipeline.
