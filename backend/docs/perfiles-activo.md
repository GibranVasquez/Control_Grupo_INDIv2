# API: Activar/desactivar perfiles

Contrato de `PUT /perfiles/:id/activo`. Implementado en
`src/controllers/perfil.controller.ts` / `src/services/perfil.service.ts`.

No hay prefijo `/api`: la URL base es la raíz del servidor (ej.
`http://localhost:4000/perfiles/:id/activo`).

## Autenticación y roles

Requiere `Authorization: Bearer <token>`. Solo **administrativo** y
**finanzas** pueden usar este endpoint (chofer no).

- `401` `{"error": "No autorizado."}` si falta el header o el token es
  inválido/venció.
- `403` `{"error": "No tienes permiso para realizar esta acción."}` si el rol
  autenticado no es `administrativo` ni `finanzas`.

### Alcance por obra (además del rol)

- `finanzas` puede activar/desactivar cualquier perfil, de cualquier obra.
- `administrativo` **solo** puede activar/desactivar perfiles que
  pertenezcan a su propia obra (`perfil.obra_id === user.obraId`). Si
  intenta sobre un perfil de otra obra: `403`
  `{"error": "No tienes acceso a los recursos de esta obra."}` —
  intencionalmente el mismo código que "no tienes el rol", para no revelarle
  a un administrativo que el perfil sí existe pero en otra obra.

## Request

```
PUT /perfiles/:id/activo
Content-Type: application/json
Authorization: Bearer <token>

{
  "activo": false
}
```

`activo` es **requerido** y debe ser un booleano literal (`true`/`false`,
no `"true"` string ni `1`).

## Response

`200`:

```json
{
  "perfil": {
    "id": "3f9b6e2a-1234-4c1a-9a3b-000000000000",
    "auth_user_id": "a1b2c3d4-...",
    "numero_empleado": "EMP-2001",
    "nombre_completo": "Juan Pérez",
    "rol": "chofer",
    "obra_id": "b2c3d4e5-...",
    "vehiculo_id": "c3d4e5f6-...",
    "area": null,
    "activo": false
  }
}
```

Shape completo de `PerfilPublico` — siempre estos 8 campos, nunca se filtra
`password_hash` ni otros campos internos (ver `perfilSerializer.ts`).

## Códigos de error

| Código | Cuándo | Body |
|---|---|---|
| `400` | Body sin `activo`, o `activo` no es booleano (ej. `"true"` string, `1`, `null`) | `{"error": "activo debe ser un booleano."}` |
| `400` | El propio usuario autenticado intenta desactivarse a sí mismo (`:id === perfilId del token` y `activo: false`) | `{"error": "No puedes desactivar tu propia cuenta."}` |
| `401` | Falta token o es inválido/venció | `{"error": "No autorizado."}` |
| `403` | Rol no es `administrativo` ni `finanzas` | `{"error": "No tienes permiso para realizar esta acción."}` |
| `403` | `administrativo` sobre un perfil de otra obra | `{"error": "No tienes acceso a los recursos de esta obra."}` |
| `404` | `:id` no corresponde a ningún perfil existente | `{"error": "Perfil no encontrado."}` |

### Casos que el frontend podría esperar como error pero **no lo son**

- **Desactivar un perfil que ya está inactivo** (o activar uno que ya está
  activo): **no es un error**. El endpoint es idempotente — responde `200`
  con el perfil sin cambios reales (`activo` queda en el mismo valor que ya
  tenía). No hay un `409` ni ningún aviso especial; si la UI quiere mostrar
  "ya estaba así", debe compararlo del lado del cliente contra el estado que
  ya tenía antes de llamar al endpoint.
- No existe una regla que impida desactivar un perfil con cargas o
  solicitudes en curso — el endpoint no valida eso, solo cambia el flag
  `activo`.

## Efecto de desactivar un perfil

- **Login nuevo**: bloqueado de inmediato. `POST /auth/login` valida
  `perfil.activo` después de verificar la contraseña; si está en `false`,
  responde `403` `{"error": "Esta cuenta está desactivada. Contacta a un administrador."}`
  aunque la contraseña sea correcta (ver `auth.service.ts`).
- **JWT ya emitido antes de desactivar**: este endpoint **no lo revoca**.
  Sigue siendo válido para la API REST hasta que expire por su cuenta
  (`JWT_EXPIRES_IN`, hoy 1 día) — no hay endpoint de "cerrar sesión"/
  invalidación server-side.
- **PowerSync**: ahí sí el corte es inmediato aunque el JWT viejo siga
  vigente, porque las sync rules consultan `perfiles.activo`/`perfiles.rol`
  en cada sync en vez de confiar en el contenido del JWT (ver "Por qué las
  sync rules no confían ciegamente..." en `powersync/POWERSYNC.md`).
