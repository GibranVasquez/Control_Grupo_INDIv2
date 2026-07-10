# PowerSync (self-hosted) — sincronización offline-first

Capa de sincronización sobre `gi_control_combustible` para que la app
funcione sin conexión y sincronice al volver a tener internet. Es
infraestructura de servidor: no reemplaza al backend REST (`../src/`), vive
al lado de él y lee la misma base de datos por replicación lógica (WAL).

Esto **no** incluye el lado de Flutter (`powersync_flutter`, esquema SQLite
local, `connect()`/`fetchCredentials()`): eso es un paso aparte de frontend.

## 1. Cómo levantar el servicio localmente

### Prerrequisitos (una sola vez por entorno)

1. **`wal_level = logical` en Postgres.** PowerSync replica por WAL lógico;
   Postgres viene por default en `wal_level = replica`, que no alcanza.

   ```sql
   ALTER SYSTEM SET wal_level = logical;
   ```

   Este cambio **requiere reiniciar el servicio de Postgres** para tener
   efecto (`sudo systemctl restart postgresql` en Arch). No pasa nada si se
   ejecuta el `ALTER SYSTEM` antes del reinicio; solo no tiene efecto hasta
   que se reinicia.

2. **Rol de solo lectura + replicación, y la publicación lógica.** Ver
   [`sql/prepare-source-db.sql`](./sql/prepare-source-db.sql) (ya ejecutado en
   este entorno de desarrollo con un password generado aleatoriamente). Crea:
   - `powersync_role`: rol con `REPLICATION` y `SELECT` en todas las tablas
     de `public` (incluye default privileges para tablas futuras). Nunca se
     reutiliza el rol de la app (`gi_app`) para esto — separa "quien escribe"
     de "quien replica".
   - `CREATE PUBLICATION powersync FOR ALL TABLES` — el nombre `powersync` es
     fijo, lo espera el servicio.

3. **`backend/powersync/.env`** (gitignorado, no `.env.example`). Contiene:
   - `PS_DATA_SOURCE_URI`: conexión a `gi_control_combustible` con
     `powersync_role`, apuntando a `127.0.0.1` (el Postgres real corre en el
     host, no en un contenedor). El servicio `powersync` usa `network_mode:
     host` en el compose para que esa conexión salga como `127.0.0.1` y
     reutilice las reglas de `pg_hba.conf` que ya confían en localhost — así
     no hay que exponer Postgres a la red bridge de Docker ni editar
     `pg_hba.conf`/`listen_addresses` (que pertenecen al usuario de sistema
     `postgres` y requerirían sudo).
   - Evita passwords con `/` o `+` en `powersync_role` y en `pg-storage`: al
     ir dentro de una URI de conexión, esos caracteres rompen el parseo (por
     eso `sql/prepare-source-db.sql` sugiere generarlas con
     `openssl rand -hex 20`, no base64).
   - `PG_STORAGE_USER` / `PG_STORAGE_PASSWORD` / `PG_STORAGE_DB`: credenciales
     del Postgres dedicado (contenedor `pg-storage`) que usa PowerSync para su
     propio libro de sincronización (buckets). **No** es la base de negocio:
     mezclar el storage de PowerSync con el esquema de la app no es soportado
     ni recomendado.
   - `PS_JWT_SECRET_B64URL` / `PS_JWT_KID`: ver sección 2.

### Levantar el servicio

```bash
cd backend/powersync
docker compose up -d
docker compose ps                 # powersync y pg-storage deben quedar "healthy"
curl http://localhost:8080/probes/liveness   # {"status":"ok"} o similar
```

El endpoint de sincronización que usará el cliente PowerSync (Flutter) es
`http://localhost:8080` (o el host donde se despliegue este contenedor).

Logs: `docker compose logs -f powersync`. Si `PS_DATA_SOURCE_URI` o el
prerrequisito de `wal_level`/publicación no están listos, el proceso arranca
igual (expone el puerto y responde liveness) pero el worker de replicación
queda en loop de error en los logs — revisa ahí antes de asumir que ya
sincroniza de verdad.

### Apagar / limpiar

```bash
docker compose down          # conserva el volumen pg_storage_data
docker compose down -v       # también borra el bucket storage (fuerza resync completo la próxima vez)
```

## 2. Cómo se conecta el JWT existente

PowerSync no tiene su propio login: valida el **mismo JWT** que ya emite
`POST /api/auth/login` (`../src/services/auth.service.ts`), firmado con el
mismo `JWT_SECRET` (HS256). El cliente Flutter arma su `fetchCredentials()`
devolviendo el token que ya guarda `credenciales_storage.dart`, sin llamar a
un endpoint aparte.

Para que PowerSync (que exige un JWT más estándar que el que ya se firmaba)
acepte ese token, `firmarToken()` ahora agrega:

- `sub`: el id del perfil (`perfil.id`) — PowerSync lo expone en las sync
  rules como `request.user_id()`.
- `aud`: `POWERSYNC_JWT_AUDIENCE` (`backend/.env`), debe ser idéntico al
  `client_auth.audience` de `config/service.yaml`.
- Header `kid`: `POWERSYNC_JWT_KID` (`backend/.env`), debe ser idéntico al
  `kid` dentro de `client_auth.jwks.keys` en `config/service.yaml`.
- Claim `vehiculoId`: se agrega al payload (antes solo tenía `perfilId`,
  `rol`, `obraId`) porque las sync rules del chofer lo necesitan.

Estos tres campos (`POWERSYNC_JWT_AUDIENCE`, `POWERSYNC_JWT_KID`) son
opcionales en `backend/.env`: si faltan, el login sigue funcionando igual
para la API REST, solo que ese token no sería válido para PowerSync.

En `config/service.yaml`, `client_auth.jwks.keys[0].k` es el mismo
`JWT_SECRET` de `backend/.env`, pero codificado en base64url (PowerSync
espera el secreto compartido como JWK de tipo `oct`, no como texto plano):

```bash
printf '%s' "$JWT_SECRET" | base64 -w 0 | tr '+/' '-_' | tr -d '='
```

Si `JWT_SECRET` cambia alguna vez, hay que regenerar `PS_JWT_SECRET_B64URL`
en `backend/powersync/.env` con el mismo comando y reiniciar el contenedor
`powersync` — de lo contrario los tokens firmados por el backend dejan de
validar contra PowerSync (la API REST no se ve afectada).

### Por qué las sync rules no confían ciegamente en `rol`/`obraId` del JWT

El JWT vive hasta `JWT_EXPIRES_IN` (1 día). Si a alguien le cambian el rol o
lo mueven de obra, un token viejo seguiría diciendo lo anterior. Por eso
`config/sync-config.yaml` no lee `request.jwt() ->> 'rol'` directamente:
cada bucket hace `SELECT ... FROM perfiles WHERE perfiles.id =
request.user_id() AND perfiles.rol = '...'`, consultando el estado real en
la base en cada sync. Así, revocar acceso (desactivar un perfil, cambiarle
la obra) tiene efecto inmediato sin esperar a que expire el token.

### Sync rules por rol (`config/sync-config.yaml`)

| Bucket | Rol | Alcance |
|---|---|---|
| `chofer_propio` | chofer | sus propias `solicitudes_autorizacion` y `cargas` |
| `chofer_obra_catalogo` | chofer | catálogo de solo lectura: `vehiculos` y `obras` de su obra (incluye su vehículo asignado) |
| `administrativo_obra` | administrativo | `solicitudes_autorizacion`, `cargas`, `vehiculos`, `perfiles` y `obras` de su obra |
| `finanzas_global` | finanzas | `solicitudes_autorizacion`, `cargas`, `vehiculos`, `perfiles`, `obras` — todas las obras, sin filtro |
| `precios_combustible_catalogo` | cualquiera autenticado | `precios_combustible` — la tabla no tiene `obra_id` (un precio vigente aplica a todas las obras), así que es el mismo catálogo para los tres roles |

No incluidas todavía (no estaban en el alcance pedido, pero seguirían el
mismo patrón de `bucket.obra_id` que `administrativo_obra` si se necesitan
más adelante): `semanas_operativas`, `fondo_semanal`, las vistas de reportes
(`vista_*`, que además PowerSync no puede replicar directo por ser vistas,
no tablas — habría que exponerlas como tabla materializada o resolverlas
client-side a partir de `cargas`/`solicitudes_autorizacion` ya sincronizadas).

## 3. Qué cambiaría para producción (PowerSync Cloud)

Self-hosted (esto) sirve para desarrollo/staging o para quien prefiere
operar su propia infraestructura. Para producción con PowerSync Cloud
cambiaría:

1. **Servicio administrado**: en vez de `docker compose up` en una máquina
   propia, se crea una instancia en [powersync.com](https://www.powersync.com)
   (o el dashboard de PowerSync Cloud) y se conecta ahí la base de datos de
   producción. Deja de existir `docker-compose.yml`/`pg-storage`: el bucket
   storage lo administra PowerSync Cloud.
2. **Conexión a Postgres**: la base de producción necesita ser alcanzable
   desde la red de PowerSync Cloud (allowlist de IPs o un endpoint privado —
   ver `configuration/source-db/security-and-ip-filtering` y
   `configuration/source-db/private-endpoints` en la documentación oficial),
   en vez de `host.docker.internal`. Sigue haciendo falta `wal_level =
   logical`, el rol de replicación y la publicación `powersync` en la base
   real.
3. **Autenticación**: seguir usando JWT propio es soportado en Cloud, pero
   HS256 con secreto compartido está pensado para desarrollo. En producción
   conviene:
   - Migrar la firma del JWT a un par de llaves asimétrico (RS256/ES256) en
     el backend, y publicar la llave pública como JWKS (`jwks_uri` en la
     config de PowerSync Cloud) en vez de pegar el secreto HS256 en la config.
   - O mantener HS256 si se acepta el trade-off, pero con un secreto distinto
     al que protege el resto de la API y rotado con más cuidado.
4. **Sync rules**: las reglas de `config/sync-config.yaml` se pegan/despliegan
   tal cual desde el dashboard o CLI de PowerSync Cloud (mismo YAML, no hay
   cambio de sintaxis).
5. **Endpoint del cliente**: la app Flutter deja de apuntar a
   `http://localhost:8080` (o el host self-hosted) y apunta a la URL de la
   instancia de PowerSync Cloud.

## 4. Verificación hecha en este entorno

- `docker --version` / `docker compose version`: ya estaban instalados, no
  hizo falta pacman. Sí hizo falta `sudo usermod -aG docker gibran` (tu
  usuario no estaba en el grupo `docker`); lo ejecutaste tú.
- `wal_level` cambiado a `logical` vía `ALTER SYSTEM` (pendiente de que
  reinicies `postgresql.service` para que tome efecto).
- `powersync_role` y `CREATE PUBLICATION powersync FOR ALL TABLES` ya creados
  en `gi_control_combustible`.
- `docker compose up -d` en `backend/powersync/` levanta `pg-storage`
  (`healthy`) y `powersync` (`healthy`, expone `/probes/liveness` en
  `:8080`, responde `{"ready":true,"started":true,...}`).
- El worker de replicación de `powersync` **ya se conecta y autentica**
  correctamente contra `gi_control_combustible` con `powersync_role` (o sea:
  la URI, la red y las credenciales están bien). El único error que queda en
  los logs es el esperado:

  ```
  wal_level must be set to 'logical', your database has it set to 'replica'.
  Please edit your config file and restart PostgreSQL.
  ```

  Es exactamente el prerrequisito pendiente de tu reinicio de Postgres — en
  cuanto reinicies, el mismo contenedor (sin cambiar nada más) debería
  empezar a replicar. Para confirmarlo: `docker compose logs -f powersync` y
  buscar que ese warning deje de repetirse / aparezca algo como "Snapshot
  completed" o actividad de replicación en vez del error.
