# Arquitectura del frontend

Feature-first en la capa de presentación, con **modelos, repositorios y estado
globales** (no duplicados por feature). Se eligió así a propósito: los tres
roles (chofer, administrativo, finanzas) leen y escriben las mismas entidades
(`Vehiculo`, `Perfil`, `SolicitudAutorizacion`...), así que separarlas en
`features/chofer/domain`, `features/administrativo/domain`, etc. terminaría en
código duplicado o en un paquete `shared` de todos modos — mismo resultado,
más carpetas.

```
lib/
├── models/       # Domain: entidades inmutables + fromJson/toJson (snake_case ↔ Dart)
├── services/     # Data: contrato abstracto por entidad + implementación PowerSync/API/caché
│   ├── <entidad>_repository.dart              # abstract class — el contrato
│   ├── powersync/powersync_<entidad>_repository.dart  # catálogos/escritura offline-first (SQLite local + sync)
│   ├── api/api_<entidad>_repository.dart      # lecturas/escrituras que van directo a la API REST
│   └── cache/                                 # caché en disco (SharedPreferences) para catálogos
├── state/        # Riverpod: un provider/notifier por caso de uso, consume services/
├── features/     # Presentación, sí separada por rol: auth/, chofer/, administrativo/, finanzas/
├── widgets/       # UI compartida entre features (AdminShell, ResponsiveCenter, badges...)
└── theme/        # Design tokens + breakpoints responsivos
```

Cada entidad usa PowerSync o la API REST directa según si necesita lectura
offline-first (catálogos, cargas, solicitudes) o no (reportes, semana
operativa, login) — ver el comentario de cabecera de cada
`Api*Repository`/`PowerSync*Repository` en `state/providers.dart` para el
porqué de cada elección.

## Regla de dependencia

`features/` → `state/` → `services/` → `models/`. Nunca al revés: un
repositorio no importa nada de `features/`, un modelo no importa nada de
`services/`. Un widget de `features/` no debe llamar a PowerSync/dio directo —
pasa siempre por un provider en `state/`.

## Patrón de un repositorio nuevo

1. `models/<entidad>.dart` — clase inmutable + `fromJson`/`toJson`.
2. `services/<entidad>_repository.dart` — `abstract class` con los métodos que
   la UI necesita (no CRUD genérico; los métodos reflejan casos de uso reales,
   ej. `listarPendientesPorObra`, no `listAll`).
3. `services/powersync/powersync_<entidad>_repository.dart` (si necesita
   lectura offline-first) o `services/api/api_<entidad>_repository.dart` (si
   siempre hay red) — implementación real.
4. `state/providers.dart` — registra el provider apuntando a la
   implementación elegida.
5. Si el dato es un catálogo casi-estático (obras, tipos): agrega cache-first
   en `state/catalogos_provider.dart` siguiendo el mismo patrón que
   `obrasCatalogoProvider`.

## Responsividad

`theme/app_breakpoints.dart` define los umbrales (móvil `<700px`, tablet
`700–1000px`, escritorio `>1000px`) vía `context.esMovil` / `esTablet` /
`esEscritorio`. Dos primitivas reutilizables:

- `ResponsiveCenter` — limita el ancho máximo de formularios/tarjetas en
  pantallas grandes (login, registro, flujo de chofer).
- `AdminShell` — sidebar fija en tablet/escritorio, `Drawer` en móvil.

Las tablas de reportes (`data_table_2`) usan `minWidth` para volverse scroll
horizontal en vez de comprimirse ilegibles en pantallas angostas — es el
patrón nativo de esa librería para tablas responsivas.
