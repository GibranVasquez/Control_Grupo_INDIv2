# API: Precios de combustible

Contrato de `/precios-combustible`. CRUD completo ya implementado en
`src/controllers/precioCombustible.controller.ts` /
`src/services/precioCombustible.service.ts`. Este documento describe el
contrato tal como está hoy para que el frontend pueda conectar la pantalla
de Precios sin preguntar nada más.

No hay prefijo `/api`: la URL base es la raíz del servidor (ej.
`http://localhost:4000/precios-combustible`).

## Autenticación y roles

Todas las rutas requieren `Authorization: Bearer <token>` (cualquier rol
autenticado puede leer). Alta y edición (`POST`, `PUT`) están restringidas
al rol **finanzas**.

Si falta el header o el token es inválido/venció: `401` (ver
`src/middlewares/auth.middleware.ts`, mensaje genérico `"No autorizado."`
siempre, sin detalle de la causa). Si el rol no alcanza: `403`
`{"error": "No tienes permiso para realizar esta acción."}`.

## Modelo `PrecioCombustible` (JSON)

Este es el shape que devuelven todos los endpoints (una lista de esto, o un
objeto suelto según el endpoint):

```json
{
  "id": "3f9b6e2a-1234-4c1a-9a3b-000000000000",
  "tipo_combustible": "diesel",
  "precio_por_litro": 24.87,
  "vigente_desde": "2026-07-01",
  "vigente_hasta": null
}
```

- `tipo_combustible`: `"magna" | "premium" | "diesel"` (único enum válido;
  cualquier otro valor es rechazado).
- `precio_por_litro`: número positivo, 2 decimales (`Decimal(10,2)` en BD,
  pero Prisma ya lo serializa como number en esta API, no como string).
- `vigente_desde` / `vigente_hasta`: fecha (`YYYY-MM-DD`, sin hora — columna
  `@db.Date`). `vigente_hasta: null` significa "precio actualmente vigente,
  sin fecha de cierre todavía".

## Regla de negocio: un solo precio "abierto" por tipo

Nunca puede haber dos precios del mismo `tipo_combustible` con
`vigente_hasta: null` al mismo tiempo. Al dar de alta un precio nuevo para
un tipo que ya tenía uno abierto, ese anterior se cierra **automáticamente**
poniéndole `vigente_hasta = vigente_desde_del_nuevo - 1 día` (ver
`crear()` en el service). No hace falta que el frontend cierre el precio
anterior manualmente antes de crear el siguiente.

## Endpoints

### `GET /precios-combustible/vigente?tipo=<tipo>`

Precio actualmente vigente de un tipo (el que tiene `vigente_desde <= hoy`
más reciente).

- Query requerido: `tipo` (`magna` | `premium` | `diesel`).
- `200`: `{ "precio": PrecioCombustible }`.
- `400`: `{ "error": "tipo debe ser uno de: magna, premium, diesel." }` si
  falta `tipo` o no es uno de los tres valores válidos.
- `404`: `{ "error": "No hay un precio vigente para este tipo de combustible." }`
  si nunca se ha dado de alta un precio para ese tipo (o si la fecha
  `vigente_desde` del único registro es futura).

### `GET /precios-combustible/historico?tipo=<tipo>`

Todos los precios (vigentes y ya cerrados) de un tipo, orden descendente
por `vigente_desde` (el más reciente primero).

- Query requerido: `tipo` (mismas reglas y error `400` que arriba).
- `200`: `{ "precios": PrecioCombustible[] }` — arreglo vacío si el tipo
  nunca tuvo un precio dado de alta (no es un 404, a diferencia de
  `/vigente`).

### `GET /precios-combustible?vigente=true|false`

Lista general, de los tres tipos de combustible a la vez.

- Query opcional `vigente`: si es exactamente el string `"true"`, devuelve
  como máximo 3 registros (el vigente de cada tipo, solo los que sí tienen
  uno vigente hoy — puede haber menos de 3 si algún tipo no tiene precio
  vigente). Cualquier otro valor (incluido omitirlo) devuelve el histórico
  completo de los tres tipos, ordenado por `tipo_combustible asc, vigente_desde desc`.
- `200`: `{ "precios": PrecioCombustible[] }`.
- No hay error posible propio de este endpoint más allá de 401/403.

### `POST /precios-combustible` (solo `finanzas`)

Da de alta un precio nuevo. Si ya había uno abierto del mismo tipo, se
cierra automáticamente (ver regla de negocio arriba).

Body:

```json
{
  "tipo_combustible": "diesel",
  "precio_por_litro": 25.10,
  "vigente_desde": "2026-08-01"
}
```

- `201`: `{ "precio": PrecioCombustible }` (el recién creado).
- `400 tipo_combustible`: `{ "error": "tipo debe ser uno de: magna, premium, diesel." }`
  si falta o no es válido.
- `400 precio_por_litro`: `{ "error": "precio_por_litro debe ser un número mayor a 0." }`
  si falta, no es número, es 0 o es negativo.
- `400 vigente_desde` (formato): `{ "error": "vigente_desde debe ser una fecha válida." }`
  si falta o no es parseable como fecha.
- `400 vigente_desde` (orden): si ya existe un precio abierto del mismo tipo
  y la fecha nueva no es **posterior** a la del abierto:
  `{ "error": "vigente_desde debe ser posterior al del precio vigente actual (YYYY-MM-DD)." }`
- `400 traslape`: si la fecha nueva cae dentro del rango de vigencia de
  **cualquier otro** precio ya registrado del mismo tipo (histórico
  incluido, no solo el abierto):
  `{ "error": "vigente_desde se solapa con otro precio ya registrado (id <uuid>)." }`

### `PUT /precios-combustible/:id` (solo `finanzas`)

Edita un precio existente. Todos los campos del body son opcionales (solo
se actualiza lo que se manda).

Body (cualquier subconjunto de):

```json
{
  "tipo_combustible": "diesel",
  "precio_por_litro": 25.50,
  "vigente_desde": "2026-08-05"
}
```

- `200`: `{ "precio": PrecioCombustible }` (ya actualizado).
- `404`: `{ "error": "Precio no encontrado." }` si `:id` no existe.
- `409 bloqueo por histórico financiero`: `{ "error": "No se puede editar: ya existen cargas registradas con este precio (no se altera el histórico financiero)." }`
  — se dispara si ya hay al menos una `carga` cuyo `precio_por_litro` y
  `fecha_carga` coinciden con el rango de vigencia de este precio (no hay
  FK directa `precio_id` en `cargas`, la coincidencia es por valor + rango
  de fechas, ver `existeCargaConEstePrecio()`). Una vez que un precio "ya se
  usó" en al menos una carga, queda congelado: ni tipo, ni monto, ni
  vigencia se pueden tocar.
- `400 precio_por_litro`: mismo mensaje que en `POST`, si se manda un valor
  inválido.
- `400 vigente_desde` (formato): mismo mensaje que en `POST`.
- `400 orden interno`: si el precio ya tiene `vigente_hasta` (está cerrado)
  y la nueva `vigente_desde` no queda antes de ese cierre:
  `{ "error": "vigente_desde debe ser anterior a vigente_hasta." }`
- `400 traslape`: mismo criterio y mismo mensaje que en `POST`, excluyendo
  el propio registro de la comparación.

Nota: `PUT` **no** cierra automáticamente ningún otro precio (esa lógica de
"cerrar el abierto anterior" solo corre en `POST`/alta). Editar un precio ya
cerrado no reabre ni afecta al que esté vigente actualmente.
