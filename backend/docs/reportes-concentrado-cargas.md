# API: Concentrado de cargas (y su exportación a Excel)

Contrato de `/reportes/concentrado-cargas` y del endpoint nuevo
`/reportes/concentrado-cargas/exportar`, agregado para el botón "Exportar
Excel" de la pantalla de Concentrado (`frontend/lib/features/administrativo/concentrado_cargas_page.dart`,
que hoy tiene ese botón con `onPressed: () {}` vacío).

No hay prefijo `/api`: la URL base es la raíz del servidor.

## Autenticación y roles

Ambos endpoints requieren `Authorization: Bearer <token>` y están
restringidos a **administrativo** (solo su propia obra) y **finanzas**
(cualquier obra). `401`/`403` con los mismos mensajes genéricos que el
resto de la API (ver `docs/perfiles-activo.md` para el detalle exacto de
esos dos códigos, es el mismo patrón en toda la API).

## Filtros (query params, ambos endpoints)

| Param | Requerido | Formato | Notas |
|---|---|---|---|
| `obra_id` | Sí | UUID | `400 {"error": "El parámetro obra_id es requerido."}` si falta. `403 {"error": "No tienes acceso a los recursos de esta obra."}` si un `administrativo` manda una obra que no es la suya. |
| `desde` | No | fecha ISO (`YYYY-MM-DD`) | Filtra `fecha_carga >= desde`. `400 {"error": "desde debe ser una fecha válida."}` si viene y no es parseable. |
| `hasta` | No | fecha ISO | Filtra `fecha_carga <= hasta`. Mismo error `400` que `desde` si es inválida. |
| `vehiculo_id` | No | UUID | **Nuevo** — antes no existía este filtro en `concentrado-cargas`. `400 {"error": "vehiculo_id debe ser un UUID válido."}` si viene y no tiene formato de UUID. No valida que el vehículo exista: si no hay cargas de ese vehículo en la obra, simplemente devuelve una lista/archivo vacío. |

Nota para el frontend: hoy la pantalla de Concentrado solo filtra por
periodo del lado del cliente (sobre la lista ya traída) y no manda
`desde`/`hasta` ni `vehiculo_id` a la API (ver
`frontend/lib/services/api/api_reportes_repository.dart`). El botón
"Filtros" de esa pantalla también está vacío (`onPressed: () {}`). Estos
tres query params ya están listos del lado del backend por si se conecta
ese botón a futuro — no es necesario mandarlos para que "Exportar Excel"
funcione (basta `obra_id`).

## `GET /reportes/concentrado-cargas` (ya existía, sin cambios de contrato)

Devuelve el concentrado como JSON. Sin cambios respecto a como ya lo conocía
el frontend, salvo el filtro opcional `vehiculo_id` agregado arriba.

`200`:

```json
{
  "cargas": [
    {
      "carga_id": "3f9b6e2a-...",
      "fecha": "2026-07-13T00:00:00.000Z",
      "responsable": "Juan Pérez",
      "vehiculo_descripcion": "Ford F-150",
      "placa": "INDI-001",
      "tipo_unidad": "vehiculo",
      "km": 120500,
      "litros": 35,
      "rendimiento_km_l": null,
      "horas_actual": null,
      "horas_anterior": null,
      "rendimiento_l_h": null,
      "precio_por_litro": 24.5,
      "tipo_combustible": "diesel",
      "importe": 857.5,
      "foto_ticket_url": "/uploads/tickets/....jpg",
      "alerta_rendimiento": null
    }
  ]
}
```

- `rendimiento_km_l`/`alerta_rendimiento` vienen `null` cuando es la primera
  carga registrada de ese vehículo (no hay `km_anterior` con el que calcular
  rendimiento) — no es un error, es esperado.
- Para maquinaria pesada (`tipo_unidad: "maquinaria"`), `km` viene `null` y
  en su lugar hay valor en `horas_actual`/`horas_anterior`/`rendimiento_l_h`
  (mutuamente excluyente con los campos de km, ver `carga.service.ts`).

## `GET /reportes/concentrado-cargas/exportar` (nuevo)

Mismos filtros y mismos errores `400`/`401`/`403` que el endpoint JSON de
arriba (reutiliza el mismo query interno). En vez de JSON, la respuesta es
el archivo `.xlsx` como descarga binaria:

```
200 OK
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="concentrado-cargas.xlsx"
```

El frontend solo necesita hacer el `GET` con el header `Authorization` y
guardar/abrir el `body` de la respuesta como archivo — no hay que parsear
nada ni armar el Excel del lado de Flutter.

### Contenido del archivo

Una sola hoja ("Concentrado de cargas") con estas columnas, en este orden:

| Columna | Origen | Notas |
|---|---|---|
| Fecha | `fecha_carga` | `YYYY-MM-DD` |
| Responsable | `chofer.nombre_completo` | |
| Vehículo | `"<marca> <modelo>"` | |
| Placas | `vehiculo.placa` | |
| Km/Horas | `km_actual` o `horas_actual` | según `tipo_unidad` del vehículo (vacío si no aplica) |
| Litros | `litros` | formato `0.00` |
| Rendimiento | `rendimiento_km_l` o `rendimiento_l_h` | según `tipo_unidad`; vacío si es la primera carga del vehículo |
| $/L | `precio_por_litro` | formato `0.00` |
| Combustible | `tipo_combustible` | |
| Importe | `monto_total` | formato moneda `$#,##0.00` |
| Ticket | `"Completo"` / `"Pendiente"` | según si `foto_ticket_url` tiene valor |
| Alerta | `alerta_rendimiento` | `"revisar"` / `"bajo"` / `"normal"` / vacío |

Última fila: `TOTAL` con la suma de `Litros` e `Importe` de todas las filas
(mismo total que ya muestra el footer de la tabla en la pantalla actual).

### Qué pasa si no hay cargas para los filtros dados

No es un error: `200` con el archivo `.xlsx` igual, con solo el encabezado y
la fila `TOTAL` en cero (sin filas de datos). El frontend puede abrir/mostrar
ese archivo igual; no hace falta manejarlo como caso especial.
