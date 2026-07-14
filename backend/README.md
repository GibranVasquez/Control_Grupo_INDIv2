# Backend — GI Control Combustible

API REST propia (Node.js + TypeScript + Express + Prisma). Este backend
**reemplaza a Supabase por completo**: no hay RLS, no hay Edge Functions ni
`auth.users` de este lado. La base de datos es PostgreSQL, administrada
directamente vía Prisma (`prisma/schema.prisma` + migraciones).

Para soporte offline-first se agrega PowerSync (self-hosted) como capa de
sincronización sobre esta misma base de datos, reutilizando el JWT que ya
emite este backend. Ver [`powersync/POWERSYNC.md`](./powersync/POWERSYNC.md).

## Estructura

```
backend/
  package.json
  tsconfig.json
  .env.example
  prisma/
    schema.prisma
    migrations/
  src/
    index.ts
    routes/
    controllers/
    services/
    middlewares/
    utils/
```

## Contrato con el frontend

El frontend (`../frontend/`) ya **no** consume esto vía `supabase_flutter`.
El contrato es una API REST tradicional: JSON sobre HTTP, autenticada con
JWT enviado en el header `Authorization: Bearer <token>`.

Esto implica que la capa de acceso a datos del frontend debe reemplazarse:
los repositorios en `frontend/lib/services/` (`perfil_repository.dart`,
`obra_repository.dart`, `vehiculo_repository.dart`, `carga_repository.dart`,
`solicitud_autorizacion_repository.dart`, `precio_combustible_repository.dart`,
`semana_operativa_repository.dart`, `reportes_repository.dart`), incluyendo
la carpeta `frontend/lib/services/supabase/`, deben pasar a llamar a esta API
en vez de al cliente de Supabase. El login deja de usar `auth.users` de
Supabase y pasa a autenticarse contra los endpoints de este backend,
guardando el JWT emitido (ver `credenciales_storage.dart`).

Las entidades que el frontend necesita seguirán siendo, conceptualmente, las
mismas que antes (perfiles, obras, vehículos, solicitudes de autorización,
cargas, precios de combustible, semanas operativas, y los resúmenes/reportes
agregados), pero ahora expuestas como endpoints REST propios en vez de tablas
y vistas de Supabase. Los modelos en `frontend/lib/models/` deben mantenerse
alineados con los shapes JSON que devuelva esta API.

## Estado de la migración

La migración descrita arriba ya está completa:

- Modelos Prisma para las 9 entidades de negocio (`prisma/schema.prisma`),
  con su migración inicial en `prisma/migracion_grupo_indi.sql` (script SQL
  puro en vez de `prisma migrate`, ver instrucciones de uso en el propio
  archivo).
- Endpoints REST para todas las entidades (`src/routes/`): perfiles
  (incluyendo activar/desactivar acceso), obras, vehículos, precios de
  combustible, solicitudes de autorización, cargas y reportes (con
  exportación a Excel).
- Flujo de autenticación completo: login, autoregistro de chofer, JWT
  (compartido con PowerSync) y manejo de roles vía middlewares.
- El frontend ya no depende de `supabase_flutter`; los repositorios en
  `frontend/lib/services/` consumen esta API.

Además, ya se agregó lo siguiente (no contemplado en el alcance original de
esta migración): almacenamiento de fotos de ticket en R2/S3-compatible (ver
[`ALMACENAMIENTO.md`](./ALMACENAMIENTO.md)), sincronización offline-first vía
PowerSync self-hosted con TLS contra Postgres en Railway (ver
[`powersync/POWERSYNC.md`](./powersync/POWERSYNC.md)), y monitoreo de errores
inesperados con Sentry (opcional, ver `SENTRY_DSN` en `.env.example`).

No hay pendientes de arquitectura abiertos. Decisiones evaluadas y pospuestas
a propósito (ej. refresh token) están documentadas en
[`DECISIONES.md`](./DECISIONES.md), no en esta sección.
