> **NOTAS INTERNAS DE DESARROLLO — no forma parte de la entrega al cliente.**
> Bitácora de pruebas manuales ad hoc contra un entorno de desarrollo local
> (usuarios semilla, base local). No son una suite automatizada ni
> documentación de producto; se conservan como referencia de qué se probó y
> qué bugs se encontraron y corrigieron en esa fecha.

# Pruebas de escenarios reales (backend + PowerSync + frontend end-to-end)

Fecha: 2026-07-10. Entorno: backend Express local (`npm run dev`, puerto 4000),
PowerSync self-hosted vía `docker compose` (`backend/powersync/`, puerto 8080)
y Postgres local (`gi_control_combustible`). Usuarios semilla usados:
`EMP-1001` (chofer, Juan Pérez), `EMP-2001` (administrativo, María López),
`EMP-3001` (finanzas, Carlos Ruiz) — los tres se dejan intactos al terminar.

**Resumen**: de las 5 pruebas pedidas, 2 encontraron bugs reales (uno de
concurrencia con impacto directo en datos, uno de configuración que bloqueaba
un flujo legítimo) — ambos corregidos y reverificados. Las otras 3 confirmaron
que el diseño ya existente se comporta correctamente, con una diferencia de
contrato documentada (no un bug) en el caso de PowerSync ante un token vencido.

| # | Prueba | Resultado inicial | ¿Se corrigió algo? |
|---|--------|--------------------|---------------------|
| 1 | Concurrencia al resolver | **Bug real**: doble "éxito" (200/200), estado final inconsistente según quién ganara la carrera | Sí — `updateMany` atómico en `solicitudAutorizacion.resolver()` y, proactivamente, en `carga.crear()` |
| 2 | Solicitudes creadas sin conexión | OK — las 3 llegan en orden, sin duplicados ni pérdida | No |
| 3 | Backend caído, PowerSync sigue vivo | OK — PowerSync no depende del backend Express para replicar/servir | No |
| 4 | Token expira a mitad de sesión | OK en general, con una diferencia de contrato documentada (ver detalle) | No (comportamiento esperado del SDK de PowerSync) |
| 5 | Carga de 50+50 y reportes | **Bug de configuración**: el rate limiter (100 req/15min) bloqueaba el propio script de prueba a mitad de camino | Sí — ajuste temporal, revertido, documentado; el límite de producción no cambió |

---

## 1. Concurrencia: dos administrativos resolviendo la misma solicitud

### Qué se hizo
Se creó una solicitud `pendiente` y se dispararon 2 requests verdaderamente
concurrentes (`curl ... & curl ... & wait`) contra
`PUT /solicitudes-autorizacion/:id/resolver`: una autorizando, otra
rechazando.

### Resultado ANTES del fix
```
REQ_A (autorizado) -> HTTP 200
REQ_B (rechazado)  -> HTTP 200
```
Ambas respuestas dijeron "éxito". El estado final en la base de datos fue
`rechazado` (el último `UPDATE` en llegar ganó silenciosamente), pero el
cliente que autorizó nunca se enteró de que su acción no quedó aplicada. Esto
es exactamente lo que la prueba buscaba detectar: **estado inconsistente sin
que nadie reciba un error**.

Causa: `resolver()` hacía `findUnique` → validar `estado === 'pendiente'` →
`update`. Entre el `findUnique` y el `update` no hay nada que impida que dos
requests concurrentes pasen ambas la validación antes de que cualquiera
escriba (el clásico *check-then-act race*).

### Corrección aplicada
`backend/src/services/solicitudAutorizacion.service.ts`: se reemplazó el
`update` final por un `updateMany` cuyo `WHERE` incluye `estado: "pendiente"`
además del `id`. Postgres evalúa el `WHERE` y aplica el `UPDATE` de forma
atómica por fila, así que de dos requests concurrentes solo uno puede
encontrar la fila todavía en `'pendiente'`. Si `count === 0`, se responde
`409 Conflict` con `"Esta solicitud ya fue resuelta."` en vez de un 200 falso.

Se detectó (por inspección, misma forma de bug) que **`carga.service.ts`**
tenía el mismo patrón: dos requests concurrentes registrando una carga contra
la misma solicitud autorizada podían pasar ambas la validación
`estado === 'autorizado'` antes de que cualquiera actualizara la solicitud a
`'cargado'`, generando dos cargas para una sola autorización. Se aplicó el
mismo tipo de corrección: la transacción (`$transaction` con callback) ahora
hace un `updateMany` condicionado (`WHERE id AND estado = 'autorizado'`) antes
de crear la carga; si no matchea ninguna fila, aborta con `409` y no se crea
la carga.

Ambos servicios ya tenían, además, una red de seguridad para la colisión de
`id` generado por el cliente (ver historial de esta migración): se conservó
tal cual, solo se le agregó el manejo explícito de `AppError` para no
enmascararlo con el nuevo catch.

### Verificación después del fix
Repetición del mismo experimento (autorizar vs. rechazar concurrente):
```
REQ_A -> HTTP 409 {"error":"Esta solicitud ya fue resuelta."}
REQ_B -> HTTP 200 (aplicado)
```
Estado final en BD consistente con la respuesta 200 (`rechazado`, con el
comentario y `resuelto_en` de esa request exacta).

Para mayor confianza se corrió una prueba de estrés: 5 rondas, cada una con
**5 requests concurrentes** autorizando la misma solicitud recién creada. En
las 5 rondas, exactamente 1 request recibió `200` y las otras 4 recibieron
`409` — nunca 2 éxitos, nunca 0.

---

## 2 y 3. Sin señal prolongado y backend caído momentáneamente

Estas dos pruebas se hicieron juntas porque ejercitan el mismo mecanismo
(la cola de subida de PowerSync) desde ángulos distintos.

### Cómo se probó
Este contenedor no tiene emulador Android, Chrome ni el target `linux/`
configurado en el proyecto Flutter, así que no se pudo conducir la UI real de
la app. En su lugar se ejercitó el código de producción real
(`ApiPowerSyncConnector` de `frontend/lib/services/powersync/powersync_client.dart`,
el esquema real, `ApiClient`/Dio real) desde `flutter test` (no `dart run`:
`flutter_secure_storage` importa `package:flutter`, que necesita `dart:ui`,
solo disponible bajo el harness de `flutter test`). Se usó un `TokenStorage`
de prueba que solo devuelve un JWT fijo en memoria, evitando tocar el backend
real de credenciales seguras (que no aplica en este entorno headless); todo
lo demás —esquema, conector, cliente HTTP— es el código real de la app.

Pasos:
1. **(Backend arriba)** Login real, luego 3 `INSERT` directos en la tabla
   local `solicitudes_autorizacion` del archivo SQLite de PowerSync,
   simulando que un chofer creó 3 solicitudes sin conexión, en orden
   (`offline-1` a `offline-3`, litros 10/20/30). `getUploadQueueStats()`
   confirmó 3 operaciones en cola.
2. **Se detuvo el backend Express** (`kill`), dejando el contenedor de
   PowerSync corriendo.
3. Se llamó `ApiPowerSyncConnector.uploadData(db)` directamente (el mismo
   método que el SDK de PowerSync invoca internamente y reintenta solo):
   lanzó `DioException [connection error]: Connection refused` — **el proceso
   no truena**, el error se puede capturar limpiamente. La cola siguió en 3
   (nada se perdió, nada se aplicó a medias).
4. Con el backend todavía caído, se golpeó `POST /sync/stream` de PowerSync
   directamente por curl (con un JWT real) → `HTTP 200` con checkpoint
   completo, y `docker compose ps` mostró `powersync`/`pg-storage` healthy en
   todo momento. Esto confirma la premisa de la prueba 3: **PowerSync no
   depende del backend Express para replicar ni para servir el stream de
   sincronización** — solo lee Postgres por WAL lógico. Lo único que depende
   del backend Express es la subida de cambios del cliente (paso 3).
5. **Se reinició el backend.**
6. Se volvió a llamar `uploadData(db)`: terminó sin lanzar, cola en 0.

### Resultado
Verificado directo en Postgres:
```
id                                    | litros_solicitados | comentario | creado_en
aaaaaaaa-0000-4000-8000-000000000001  | 10.00               | offline-1  | 16:11:23.541
aaaaaaaa-0000-4000-8000-000000000002  | 20.00               | offline-2  | 16:11:23.564
aaaaaaaa-0000-4000-8000-000000000003  | 30.00               | offline-3  | 16:11:23.577
```
Las 3 llegaron con su id exacto generado en el cliente (sin duplicados, sin
reconciliación de ids — ver el cambio de la migración anterior que hizo esto
posible), en el mismo orden en que se crearon, sin pérdidas. No se necesitó
ningún cambio de código: el diseño existente (conector + backend aceptando el
id del cliente) ya se comporta correctamente.

---

## 4. Token expirado a mitad de sesión

### Cómo se probó
Se generó un JWT con el mismo secreto/claims/opciones que
`firmarToken()` en `auth.service.ts` (mismo `JWT_SECRET`, `aud`, `kid`), pero
con `expiresIn: '12s'`, para poder usarlo de inmediato y luego esperar a que
venza sin depender de temporizadores de 1 día.

- **Uso inmediato** (token recién emitido):
  - `GET /auth/perfil-actual` → `200`, perfil real devuelto.
  - `POST /sync/stream` (PowerSync) → `200`, checkpoint real devuelto.
- **Tras esperar a que venza** (~16s después, confirmado comparando `exp` del
  token contra la hora actual):
  - `GET /auth/perfil-actual` → **`401` limpio**: `{"error":"No autorizado."}`
    (el middleware de auth captura `jwt.TokenExpiredError` explícitamente).
  - `POST /sync/stream` (PowerSync) → **`200`**, con cuerpo
    `{"token_expires_in":0}` y sin datos de checkpoint.

### Hallazgo (no es un bug, es una diferencia de contrato)
PowerSync **no** responde 401 a un JWT bien formado pero vencido en
`/sync/stream`: acepta la conexión HTTP (200) y, dentro del cuerpo
`ndjson`, manda `{"token_expires_in": 0}` en vez de servir datos — es su
forma de avisarle al cliente que debe refrescar credenciales antes de que la
conexión sirva algo. Se confirmó que esto es intencional y no un fallo de
validación: con un token realmente inválido (no un JWT bien formado),
PowerSync sí responde `401` con un error claro
(`{"error":{"code":"PSYNC_S2101","description":"Token is not a well-formed JWT..."}}`).
El propio paquete `powersync` (código fuente en
`~/.pub-cache/hosted/pub.dev/powersync-2.3.1/test/`) usa exactamente este
campo `token_expires_in` en sus fixtures de prueba, confirmando que es parte
del protocolo esperado, no un artefacto de este backend self-hosted.

**Implicación para la app** (no requirió cambio de código, queda documentada
para referencia futura): como no hay flujo de refresh-token —el JWT vive fijo
hasta `JWT_EXPIRES_IN` (1 día)—, si el token vence mientras PowerSync sigue
"conectado", el conector seguirá recibiendo `token_expires_in: 0` sin datos
nuevos hasta que el usuario dispare una llamada REST normal, esa sí reciba el
401 limpio, `ApiClient` limpie la sesión (`onUnauthorized`) y la UI regrese a
`/login` (ver `state/providers.dart`) — momento en el que un login nuevo deja
un JWT fresco que PowerSync vuelve a aceptar. Es decir: la recuperación ya
existe, solo pasa por la vía REST, no por PowerSync directamente.

En ambos casos (API y PowerSync), tras el token vencido, se confirmó que
ningún proceso truena: `GET /health` y `GET /probes/liveness` siguieron
respondiendo con normalidad.

---

## 5. Carga de trabajo básica: 50 solicitudes + 50 cargas + reportes

### Primer intento: bug de configuración descubierto
Un script simple (bash + curl) creó, para cada una de 50 iteraciones:
solicitud → resolver (autorizar) → carga. Son 150 requests HTTP secuenciales.
El primer intento (sin revisar los códigos de respuesta) terminó con solo
32/50 solicitudes y 31/50 cargas realmente insertadas.

Causa: `limitadorGlobal` (`backend/src/middlewares/rateLimit.ts`) limita a
**100 requests / 15 min por IP**, y el propio flujo de prueba (150 requests)
ya lo excede por sí solo, sin contar las decenas de requests de las pruebas
1-4 corridas antes en la misma ventana. `RateLimit-Remaining: 0` lo confirmó.
Esto es una limitación real y esperable de un límite pensado para tráfico de
un solo cliente normal, no para una carga administrativa en lote — vale la
pena que quien opere el backend lo tenga presente si algún día se necesita un
endpoint de importación masiva real (hoy no existe uno).

### Corrección para poder correr la prueba
Se subió temporalmente `limitadorGlobal.max` a `2000` (marcado en el código
como `TEMP-PRUEBAS-CARGA`), se reinició el backend (limpia el contador en
memoria de `express-rate-limit`), se corrió la prueba completa, y **se
revirtió el valor a 100** al terminar, reiniciando de nuevo y confirmando por
los headers `RateLimit-*` que quedó en el límite original de producción. No
quedó ningún cambio de este límite en el código.

### Resultado de la carga (ya sin el límite de por medio)
50 solicitudes creadas + 50 resueltas (autorizado) + 50 cargas creadas: **150
requests en ~3.7s, 0 errores**.

Tiempos de los endpoints de reportes (obra "Los Pinos", ya con el dataset de
prueba insertado — el catálogo total en ese momento era ~106 solicitudes /
~85 cargas, no es un dataset de escala productiva, es la carga "básica" que
pidió la prueba):

| Endpoint | 5 corridas (segundos) |
|---|---|
| `GET /reportes/concentrado-cargas` | 0.0107, 0.0060, 0.0073, 0.0059, 0.0038 |
| `GET /reportes/resumen-financiero-semanal` | 0.0040, 0.0044, 0.0048, 0.0048, 0.0028 |
| `GET /reportes/resumen-financiero-consolidado` | 0.0041, 0.0030, 0.0025, 0.0037, 0.0043 |

Los tres se mantuvieron por debajo de ~11ms en todas las corridas — tiempo de
respuesta razonable sin ningún ajuste adicional.

### Limpieza
Se borraron exactamente las 50 solicitudes (marcadas con
`comentario = 'CARGA_PRUEBA_50'`) y las 50 cargas correspondientes
(por `vehiculo_id` + rango de `km_anterior` usado solo en esta prueba),
además de los registros más pequeños generados por las pruebas 1-3 de este
mismo documento (7 solicitudes de la prueba de concurrencia, identificadas
por id exacto tras confirmar que el propio `resolver()` sobrescribe el
`comentario` original con el de la resolución — así que no bastaba con
buscar el comentario de creación —, y 3 solicitudes `aaaaaaaa-0000-4000-8000-%`
de la prueba de sincronización offline). Se verificó el conteo final y que
los 3 perfiles semilla (`EMP-1001`, `EMP-2001`, `EMP-3001`) siguen intactos.
Los datos de solicitudes/cargas preexistentes de sesiones anteriores a este
documento (por ejemplo, las de la migración de ids de cliente) se dejaron
sin tocar, ya que no son "los 50+50" de esta prueba.

---

## Cambios de código que quedaron aplicados

- `backend/src/services/solicitudAutorizacion.service.ts`: `resolver()` ahora
  usa `updateMany` condicionado a `estado = 'pendiente'` y responde `409` si
  no matchea ninguna fila (antes: `update` sin condición de carrera, `400`).
- `backend/src/services/carga.service.ts`: `crear()` ahora hace, dentro de la
  misma transacción, un `updateMany` condicionado a
  `estado = 'autorizado'` sobre la solicitud antes de crear la carga, con
  `409` si no matchea (antes: `update` sin condición de carrera).
- `backend/src/middlewares/rateLimit.ts`: sin cambios netos (se probó y
  revirtió un ajuste temporal para la prueba 5; el límite de producción
  sigue en 100 req/15min).

Ningún archivo de `frontend/` cambió como resultado de esta batería de
pruebas (los hallazgos de las pruebas 2-4 no requirieron cambios ahí).
