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

## Cómo correr esto en local (de cero)

Prerrequisitos: Node.js (usado en desarrollo: v26; no hay `engines` fijado en
`package.json`, versiones recientes de Node 18+ deberían funcionar igual) y
PostgreSQL corriendo en local o accesible por red. Docker es opcional, solo
si además quieres levantar PowerSync (paso 7).

1. **Base de datos.** Crea un rol y una base de datos vacíos para la app
   (ejemplo con un Postgres local; ajusta si usas otro):
   ```sql
   create role gi_app login password 'TU-PASSWORD';
   create database gi_control_combustible owner gi_app;
   ```
   Aplica el esquema con el script SQL puro del proyecto — **no** se usa
   `prisma migrate`:
   ```bash
   psql "postgresql://gi_app:TU-PASSWORD@localhost:5432/gi_control_combustible" \
     -f prisma/migracion_grupo_indi.sql
   ```
   (ver el encabezado del propio archivo para el caso de un proyecto nuevo
   sin `schema.prisma` todavía — no es este caso).

2. **Variables de entorno.**
   ```bash
   cp .env.example .env
   ```
   Rellena al menos `DATABASE_URL` (la base del paso 1) y `JWT_SECRET`
   (cualquier string en desarrollo). El resto (`R2_*`, `SENTRY_DSN`,
   `POWERSYNC_JWT_*`) son opcionales para desarrollo local sin esas
   integraciones — ver los comentarios de cada variable en `.env.example`.

3. **Dependencias y cliente Prisma.**
   ```bash
   npm install
   npx prisma generate
   ```
   (no hay hook `postinstall` que corra `prisma generate` automáticamente;
   hazlo a mano tras cada `npm install` si cambiaste `schema.prisma`.)

4. **Datos semilla.**
   ```bash
   npm run seed
   ```
   Crea (o actualiza, es idempotente vía `upsert`) 3 perfiles de prueba:
   `EMP-1001` (chofer), `EMP-2001` (administrativo), `EMP-3001` (finanzas),
   todos con password `1234`. Nota: estos 3 usuarios semilla tienen guion en
   el usuario (`EMP-1001`), que ya **no** cumpliría la regex de formato que
   ahora exige `POST /auth/registro-chofer` para cuentas nuevas
   (`^[a-zA-Z0-9._]+$`, ver `src/utils/validacion.ts#esUsuarioValido`) — no
   es una inconsistencia: el seed inserta directo vía Prisma sin pasar por
   esa validación (que solo corre en la creación por HTTP), y el login nunca
   revalida el formato de una cuenta ya existente, solo busca por el valor
   guardado tal cual.

5. **Arrancar el servidor.**
   ```bash
   npm run dev
   curl http://localhost:4000/health   # {"status":"ok"}
   ```

6. **Verificación.**
   ```bash
   npx tsc --noEmit
   npm test
   npm run lint
   ```

7. **(Opcional) PowerSync self-hosted**, para sincronización offline-first —
   ver [`powersync/POWERSYNC.md`](./powersync/POWERSYNC.md). Requiere Docker
   y credenciales de conexión al Postgres de Railway compartido por el
   equipo (pídelas a quien administre el proyecto; no se generan
   localmente, y los prerrequisitos de PowerSync sobre esa base ya están
   aplicados una sola vez — ver sección 1 de ese documento).

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
