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

## Pendiente

- Definir los modelos Prisma (`prisma/schema.prisma`) equivalentes a las
  entidades de negocio y generar la primera migración.
- Diseñar los endpoints REST (rutas, payloads, códigos de estado) que
  reemplazan a las tablas/vistas antes servidas por Supabase.
- Definir el flujo de autenticación (registro/login, emisión y expiración de
  JWT, hashing de contraseñas) y el manejo de roles (antes `perfiles.rol`).
- Coordinar con el frontend el reemplazo de los repositorios en
  `frontend/lib/services/` y la eliminación de la dependencia
  `supabase_flutter` una vez que la API esté lista.
