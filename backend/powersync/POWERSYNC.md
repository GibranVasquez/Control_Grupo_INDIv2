# PowerSync (self-hosted) — sincronización offline-first

Capa de sincronización sobre `gi_control_combustible` para que la app
funcione sin conexión y sincronice al volver a tener internet. Es
infraestructura de servidor: no reemplaza al backend REST (`../src/`), vive
al lado de él y lee la misma base de datos por replicación lógica (WAL).

Esto **no** incluye el lado de Flutter (`powersync_flutter`, esquema SQLite
local, `connect()`/`fetchCredentials()`): eso es un paso aparte de frontend.

## 1. Cómo levantar el servicio localmente

### Prerrequisitos (ya completados una sola vez, sobre la base compartida de Railway — no hay que repetirlos al clonar el repo)

Un clon nuevo del repo **no necesita rehacer nada de esta subsección**: ya
están aplicados sobre la base de Railway que comparte todo el equipo. Se
documentan aquí solo como referencia de qué existe y por qué, y por si algún
día se necesita otra base (otro entorno, otro Postgres) desde cero.

1. **`wal_level = logical` en el Postgres de origen.** PowerSync replica por
   WAL lógico; Postgres viene por default en `wal_level = replica`, que no
   alcanza.

   ```sql
   ALTER SYSTEM SET wal_level = logical;
   ```

   Este cambio requiere reiniciar el servicio de Postgres para tener efecto.
   Ya está aplicado en la base de Railway (confirmado por la replicación
   activa, ver sección 5). Si alguna vez se necesita repetir esto contra un
   Postgres **local** (no es el caso de Railway, que administra esto por su
   cuenta), sería `sudo systemctl restart postgresql` en Arch o el equivalente
   de tu gestor de paquetes.

2. **Rol de solo lectura + replicación, y la publicación lógica.** Ver
   [`sql/prepare-source-db.sql`](./sql/prepare-source-db.sql) — **ya ejecutado
   contra la base de Railway** con un password generado aleatoriamente (es la
   credencial que va en `PS_DATA_SOURCE_URI`, ver punto 3). Crea:
   - `powersync_role`: rol con `REPLICATION` y `SELECT` en todas las tablas
     de `public` (incluye default privileges para tablas futuras). Nunca se
     reutiliza el rol de la app (`gi_app`) para esto — separa "quien escribe"
     de "quien replica".
   - `CREATE PUBLICATION powersync FOR ALL TABLES` — el nombre `powersync` es
     fijo, lo espera el servicio.

3. **`backend/powersync/.env`** (gitignorado, no `.env.example`). Contiene:
   - `PS_DATA_SOURCE_URI`: conexión a `gi_control_combustible` con
     `powersync_role`, apuntando **a Railway** (no a un Postgres local — ver
     sección 5 para `sslmode`/CA pinneada, obligatorios contra Railway). El
     compose usa la red bridge normal de Docker (no `network_mode: host`,
     que solo aplicaría si el origen fuera un Postgres en el mismo host).
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
- `sslmode: verify-ca` con `cacert` pinneado (ver sección 5): probado con
  `psql` directo contra Railway (conecta y valida) y aplicado en
  `config/service.yaml` con `docker compose up -d --force-recreate
  powersync`. Confirmado en logs tras el recreate: sin errores de
  certificado, `"Replicating op 0 ..."` — sigue replicando igual que con
  `sslmode: disable`, ahora cifrado.

## 5. Fuente de datos en Railway: `sslmode`, CA pinneada y redes privadas

`PS_DATA_SOURCE_URI` en `backend/powersync/.env` ya no apunta al Postgres
local: apunta a la base de Railway (`hayabusa.proxy.rlwy.net:<puerto>/railway`),
usando el mismo `wal_level = logical`, `powersync_role` y
`CREATE PUBLICATION powersync FOR ALL TABLES` de
[`sql/prepare-source-db.sql`](./sql/prepare-source-db.sql) — el script
aplica igual sin importar dónde viva el Postgres. La replicación inicial y
el streaming ya corren correctamente contra Railway (ver logs con
`docker compose logs -f powersync`: snapshot de las tablas de negocio y
`"Activated new replication stream"`).

### `sslmode: verify-ca` con la CA autofirmada de Railway pinneada

`config/service.yaml` usa `sslmode: verify-ca` + `cacert: !env PS_PG_CACERT`
para esta conexión. El tráfico de replicación va **cifrado** entre donde
corra este `docker-compose` y Railway, y PowerSync valida que el servidor
presente un certificado firmado por esa CA — no es `sslmode: disable`.

Por qué no bastaba con `verify-full`/`verify-ca` "a secas" (sin `cacert`):

- El schema de configuración de PowerSync solo acepta `verify-full`,
  `verify-ca` o `disable` para `sslmode` — no existe un modo "cifra pero no
  valides el certificado" (el `sslmode=require` de libpq no es una opción
  válida aquí).
- Contra las CAs de confianza del sistema, `verify-full` y `verify-ca`
  fallan con `certificate verify failed`: el proxy de Railway sirve el
  certificado que expone el propio Postgres al arrancar con TLS activado
  por default — un cert autofirmado (`CN=localhost`, emitido por una CA
  propia `CN=root-ca`), no uno de una CA pública. Verificado con:

  ```bash
  openssl s_client -starttls postgres -connect hayabusa.proxy.rlwy.net:<puerto> \
    -verify_return_error </dev/null
  # verify error:num=19:self-signed certificate in certificate chain
  ```

- La solución no es apagar TLS, es **fijar (pin) esa CA autofirmada
  explícitamente**: el schema de PowerSync sí tiene un campo `cacert` para
  esto en la conexión postgresql (ver
  `https://unpkg.com/@powersync/service-schema@latest/json-schema/powersync-config.json`,
  y el código que lo consume en
  `libs/lib-postgres` del repo `powersync-ja/powersync-service` —
  `normalizeConnectionConfig` pasa `cacert` tal cual, como contenido PEM
  literal, no como ruta de archivo). Con esa CA fijada:

  ```bash
  psql "host=hayabusa.proxy.rlwy.net port=<puerto> dbname=railway \
    user=powersync_role sslmode=verify-ca sslrootcert=railway-ca.pem" -c "select 1;"
  # funciona: conecta cifrado y valida la cadena contra esa CA
  ```

- No se usa `verify-full`: el cert hoja dice `CN=localhost` (no el hostname
  público de Railway), así que la verificación de hostname de `verify-full`
  fallaría igual. `verify-ca` no valida el hostname, solo que la cadena de
  certificados esté firmada por la CA pinneada — que es exactamente la
  garantía que queremos aquí (protege contra MITM en el internet público;
  no protege contra alguien que ya controla el propio Postgres de Railway,
  pero ese es un nivel de confianza que ya dábamos por hecho).

### Cómo se obtuvo y dónde vive `PS_PG_CACERT`

El segundo certificado de la cadena que sirve el proxy (el autofirmado,
`CN=root-ca`) se extrajo con:

```bash
openssl s_client -starttls postgres -connect hayabusa.proxy.rlwy.net:<puerto> \
  -showcerts </dev/null 2>/dev/null | \
  awk '/BEGIN CERT/{c++} c==2{print} /END CERT/ && c==2{exit}'
```

y se guardó como `PS_PG_CACERT` en `backend/powersync/.env` (gitignorado),
con los saltos de línea del PEM escapados como `\n` literales dentro de
comillas dobles (así los interpreta el parser de env files de Compose). Ver
`.env.example` para el formato exacto y el mismo comando de extracción.

**Riesgo a vigilar**: esta CA la genera el propio proceso de Postgres al
inicializar TLS (no es algo que Railway documente como estable ni
rotable a demanda desde su dashboard). Si Railway alguna vez reinicializa
el volumen de datos de ese Postgres (no un simple restart — un restart
normal conserva el mismo cert porque vive en el volumen), esta CA cambiaría
y `verify-ca` empezaría a fallar en los logs de `powersync` con
`certificate verify failed`. Si eso pasa: re-ejecutar el comando de arriba
para capturar la CA nueva, actualizar `PS_PG_CACERT` en `.env`, y
`docker compose up -d --force-recreate powersync`. Mientras tanto, esto no
requiere ningún cambio de infraestructura ni migración.

### Investigación de "Private Networking" de Railway como alternativa

Railway ofrece redes privadas entre servicios de un mismo proyecto
([docs.railway.com/networking/private-networking](https://docs.railway.com/private-networking)):
cada servicio obtiene un nombre DNS interno `<servicio>.railway.internal`,
alcanzable solo a través de un mesh cifrado con Wireguard **entre servicios
del mismo proyecto y ambiente** en la infraestructura de Railway. El
tráfico ahí nunca sale a internet público, lo que habría resuelto el
problema de raíz (no haría falta preocuparse por `sslmode` en absoluto,
porque no habría superficie pública que proteger).

Confirmado que **no es viable en el setup actual**: esta red privada solo
es alcanzable desde otros servicios que corran dentro de la infraestructura
de Railway, no desde una máquina externa (como la que corre este
`docker-compose` hoy). Verificado con una prueba de DNS desde esta máquina:

```
$ getent hosts postgres.railway.internal
(sin salida — no resuelve)
```

Esto es esperado y consistente con la documentación de Railway: el
`railway.internal` de un proyecto no es un DNS público, solo resuelve
dentro de su propia red interna.

### ¿Sigue teniendo sentido migrar a la red privada? (opcional, no bloqueante)

Con `verify-ca` + CA pinneada, el problema original (tráfico sin cifrar) ya
está resuelto sin tocar infraestructura. Migrar `powersync`/`pg-storage` a
correr **dentro de Railway** (mismo proyecto que el Postgres) seguiría
siendo una mejora, pero ahora es una cuestión de superficie de exposición y
operación, no de cifrado:

- Ventaja real que quedaría pendiente: el tráfico de replicación dejaría de
  pasar por el proxy público (`*.proxy.rlwy.net`) del todo, reduciendo la
  superficie atacable (nadie fuera de Railway podría siquiera intentar
  conectarse a ese puerto) y evitando depender de que Railway no rote la CA
  autofirmada (ver riesgo arriba).
- Costo: el `docker-compose.yml` actual (`powersync` + `pg-storage`,
  pensado para correr en una máquina de desarrollo con `network_mode:
  host`) tendría que convertirse en servicios de Railway (o usar PowerSync
  Cloud, ver sección 3), y `PS_DATA_SOURCE_URI` pasaría a apuntar a
  `<servicio-postgres>.railway.internal:5432` en vez del proxy público.

Si se decide hacerlo más adelante, los pasos serían:

1. Migrar `docker-compose.yml` (`powersync` + `pg-storage`) a servicios de
   Railway (o el storage administrado equivalente si se usa PowerSync
   Cloud — ver sección 3).
2. Una vez desplegado ahí, confirmar el nombre exacto del servicio de
   Postgres en el dashboard/CLI de Railway para armar el
   `<servicio>.railway.internal`.
3. Cambiar `PS_DATA_SOURCE_URI` a esa URI interna; en ese punto `sslmode:
   disable` sí sería aceptable para esa conexión específica (tráfico
   intra-red de Railway, nunca sale a internet), aunque `verify-ca` con la
   CA pinneada también seguiría funcionando ahí sin cambios.

No es una tarea bloqueante para producción: `verify-ca` ya resuelve el
riesgo de fondo (cifrado + validación de certificado) mientras PowerSync
corra fuera de Railway.
