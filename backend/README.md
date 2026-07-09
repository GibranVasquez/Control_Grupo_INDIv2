# Backend — GI Control Combustible

Este directorio es propiedad del equipo de backend. El frontend (`../frontend/`) solo lo consume vía `supabase_flutter` + PowerSync; no se modifica desde este repo del lado Flutter.

## Estructura esperada

```
backend/
  supabase/
    migrations/   # esquema SQL (tablas, RLS, vistas)
    functions/    # Edge Functions (Deno)
```

## Contrato con el frontend

El frontend asume las siguientes tablas y vistas (ver `frontend/lib/models/` para los campos exactos consumidos):

- `perfiles`, `obras`, `vehiculos`
- `solicitudes_autorizacion`, `cargas`
- `precios_combustible`, `semanas_operativas`
- Vistas: `vista_consumo_vehiculo_semanal`, `vista_concentrado_cargas`, `vista_resumen_financiero_semanal`

Cualquier cambio de nombre de columna/tabla o de tipo de dato debe reflejarse en `frontend/lib/models/` para no romper la serialización.

## Pendiente de Fase 0 (ver plan de trabajo del frontend)

- Confirmar si la autorización es binaria o parcial (`litros_autorizados`).
- Confirmar regla de disparo del comentario obligatorio (comparación contra `tope_litros_semanal` / `vista_consumo_vehiculo_semanal`).
- Entregar al frontend: URL del proyecto Supabase + `anon key`, endpoint/credenciales de PowerSync.
- Confirmar lectura de rol: `perfiles.rol` vía `auth_user_id = auth.uid()`.
