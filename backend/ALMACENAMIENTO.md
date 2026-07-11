# Almacenamiento de fotos de ticket

Las fotos de ticket de carga (`POST /cargas/:id/foto-ticket`) pasan por una
abstracción en `src/services/storage.service.ts` con dos implementaciones:

- **`local`** (default): escribe a `backend/uploads/tickets/` y sirve los
  archivos desde esta misma API (`/uploads/...`, ver `src/index.ts`). Es lo
  que se usa hoy en desarrollo. **No sirve en producción en Railway/Render**:
  el filesystem no es persistente, así que cada redeploy borra las fotos ya
  subidas.
- **`s3`**: sube a un bucket S3-compatible. Pensado para **Cloudflare R2**
  (tiene una capa gratuita generosa y no cobra por egress), pero cualquier
  proveedor compatible con la API de S3 funciona igual con las mismas
  variables.

Cuál se usa se controla con la variable de entorno `STORAGE_PROVIDER`
(`local` o `s3`, ver `.env.example`). Mientras se quede en `local` (o vacía),
todo sigue funcionando exactamente igual que antes — las variables `R2_*` no
se leen ni son necesarias.

## Cuándo migrar a R2

En cuanto se despliegue el backend a Railway/Render para que otras personas
lo usen de forma continua (no solo pruebas locales), conviene activar `s3`
para no perder fotos en cada redeploy.

## Cómo crear una cuenta gratuita de Cloudflare R2

1. Entra a https://dash.cloudflare.com/ y crea una cuenta (o inicia sesión
   si ya tienes una).
2. En el menú lateral, entra a **R2 Object Storage**. La primera vez pide
   activar R2 en la cuenta (no requiere tarjeta para la capa gratuita: 10 GB
   de almacenamiento y 1 millón de operaciones Clase A/mes al momento de
   escribir esto — confirma los límites vigentes en
   https://developers.cloudflare.com/r2/pricing/ antes de decidir).
3. Crea un bucket, por ejemplo `gi-control-combustible-tickets`. Ese nombre
   es `R2_BUCKET_NAME`.
4. Anota el **Account ID** que aparece en la esquina superior derecha de la
   página de R2 (o en cualquier página del dashboard) — es `R2_ACCOUNT_ID`.
5. Ve a **R2 > Manage R2 API Tokens** (o "API Tokens" en el menú de R2) y
   crea un token con permiso de **Object Read & Write**, limitado al bucket
   del paso 3 si la UI lo permite. Al crearlo te muestra:
   - **Access Key ID** → `R2_ACCESS_KEY_ID`
   - **Secret Access Key** → `R2_SECRET_ACCESS_KEY` (solo se muestra una vez,
     guárdalo en un gestor de contraseñas o directamente en las variables de
     entorno de Railway/Render — no lo commitees).
6. Para servir las fotos públicamente necesitas una URL pública para el
   bucket. Dos opciones:
   - **Dominio propio** (recomendado para producción): en el bucket, ve a
     **Settings > Custom Domains**, conecta un subdominio tuyo (ej.
     `tickets.tudominio.com`) que ya administres en Cloudflare. `R2_PUBLIC_URL`
     sería `https://tickets.tudominio.com`.
   - **Dev subdomain de R2** (rápido para probar, no pensado para producción
     estable): en **Settings > Public Access**, activa el "R2.dev subdomain".
     Te da una URL tipo `https://pub-xxxxxxxx.r2.dev`; esa es tu
     `R2_PUBLIC_URL`.

## Cómo activarlo

1. Define en el `.env` del backend (o en las variables de entorno de
   Railway/Render):
   ```
   STORAGE_PROVIDER=s3
   R2_ACCOUNT_ID=...
   R2_ACCESS_KEY_ID=...
   R2_SECRET_ACCESS_KEY=...
   R2_BUCKET_NAME=...
   R2_PUBLIC_URL=https://...
   ```
2. Reinicia el backend. Las fotos nuevas se suben a R2; las que ya estaban
   en `uploads/tickets/` en modo local **no se migran automáticamente** (si
   hay fotos viejas que importa conservar, hay que subirlas manualmente al
   bucket antes de cambiar `STORAGE_PROVIDER`, con la misma key relativa
   `tickets/<archivo>` que usa `LocalStorageService` para que las URLs ya
   guardadas en la base de datos sigan resolviendo).
3. Para volver a `local`, basta con quitar/cambiar `STORAGE_PROVIDER` — no
   requiere ningún otro cambio de código.
