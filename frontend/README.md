# gi_control_combustible — frontend

App móvil/escritorio en Flutter para el control de cargas de combustible de
INDI: registro de cargas por chofer, autorización por administrativo, y
seguimiento financiero por finanzas.

- Arquitectura y convenciones del código: ver [ARCHITECTURE.md](ARCHITECTURE.md).
- Instrucciones de compilación por plataforma: ver [BUILD.md](BUILD.md).

## Stack

- Flutter + Riverpod (estado) + go_router (navegación).
- PowerSync (SQLite local con sincronización) + API REST propia (`dio`) como
  fuentes de datos — ver `lib/services/powersync/` y `lib/services/api/`.
- `flutter_secure_storage`/`shared_preferences` para almacenamiento local,
  `local_auth` para biometría, `sentry_flutter` para monitoreo de errores.

## Desarrollo local

1. Backend corriendo (ver `../backend/README.md`) y servicio de PowerSync
   levantado (`../backend/powersync/`).
2. `flutter pub get`
3. `flutter run --dart-define=API_URL=http://localhost:4000 --dart-define=POWERSYNC_URL=http://localhost:8080`

## Tests

`flutter test` — incluye un test de integración (`cola_fotos_ticket_offline_test.dart`)
que corre contra el backend real en `localhost:4000` (debe estar levantado).
