# Decisiones y evaluaciones

Este archivo registra análisis de "¿deberíamos hacer X?" que se evaluaron a
propósito y se resolvieron con un **no, todavía no** — para no repetir la
discusión más adelante ni perder el razonamiento detrás. No es un roadmap de
pendientes (eso vive donde corresponda a cada feature); es la memoria de por
qué algo que se consideró no se implementó.

## Refresh Token — evaluación (no implementado)

**Estado actual:** el login emite un JWT de un solo tipo (`JWT_EXPIRES_IN`,
hoy `1d`, ver `src/services/auth.service.ts`). Cuando expira, el cliente debe
volver a autenticarse por completo — no hay endpoint de refresh ni logout en
el backend (el JWT es stateless; "cerrar sesión" hoy es 100% del lado del
cliente, ver `frontend/lib/state/auth_controller.dart`).

### Qué implicaría implementarlo

**Backend:**
- Tabla nueva `refresh_tokens` (migración de Prisma): `id`, `perfil_id` (FK),
  `token_hash` (nunca guardar el token en claro, igual que `password_hash`),
  `creado_en`, `expira_en`, `revocado_en` nullable. Se guarda el hash, no el
  token, para que un dump de la base no sea equivalente a robar sesiones
  activas.
- `POST /auth/login` pasaría a devolver también un refresh token (vida larga,
  días/semanas) además del JWT de acceso (vida corta).
- Endpoint nuevo `POST /auth/refresh`: recibe el refresh token, valida contra
  el hash guardado y que no esté vencido/revocado, emite un JWT de acceso
  nuevo. Con rotación (recomendado): además invalida el refresh token usado y
  emite uno nuevo, para poder detectar reuso de un token robado (si alguien
  presenta un refresh token ya rotado, es señal de que fue comprometido y se
  pueden revocar todos los de ese perfil).
- Endpoint nuevo `POST /auth/logout` (hoy no existe): marcar `revocado_en` en
  el refresh token correspondiente. Sin esto, el refresh token seguiría
  siendo válido en el servidor aunque el cliente "cierre sesión" localmente.

**Frontend (Flutter, fuera del alcance de este backend pero relevante para
dimensionar el cambio):**
- `TokenStorage` (o equivalente) tendría que guardar dos tokens en vez de
  uno, y el cliente HTTP necesitaría un interceptor que, ante un 401 por JWT
  vencido, llame a `/auth/refresh` antes de reintentar la request original
  (y solo si eso también falla, forzar login completo).
- Coordinar con el flujo de PowerSync, que hoy reutiliza el mismo JWT del
  login (ver `powersync/POWERSYNC.md`): al refrescar el JWT de acceso habría
  que decidir si también se reconecta PowerSync con el token nuevo o si tolera
  seguir con el viejo hasta su propia expiración.

Tamaño estimado: no es trivial pero tampoco es una reescritura — una
migración, dos endpoints nuevos y un interceptor en el cliente HTTP del
frontend. El costo real está más en las decisiones de seguridad (rotación,
detección de reuso, expiración de cada token) que en el volumen de código.

### Por qué se decidió no hacerlo ahora

El problema de UX que un refresh token resolvería — no forzar al usuario a
volver a teclear su número de empleado y contraseña cuando el JWT expira —
**ya está cubierto** por el login con biometría: `auth_controller.dart`
guarda las credenciales en almacenamiento seguro y las reutiliza tras un
`autenticar()` biométrico exitoso (`iniciarSesionConBiometria`), sin pedirle
nada al usuario más que su huella/Face ID. El JWT vencido simplemente
dispara un re-login transparente para el usuario, aunque técnicamente sea un
login completo y no un refresh.

Dado eso, agregar un refresh token ahora sumaría superficie de seguridad
(tabla nueva, endpoints nuevos, lógica de rotación/revocación) a cambio de un
beneficio de UX marginal, porque el caso que de verdad le importa al usuario
(no volver a teclear la contraseña) ya está resuelto por otro camino.

### Cuándo tendría sentido retomarlo

Si en algún momento se decide **acortar la vida del JWT** por seguridad (por
ejemplo, de `1d` a algo del orden de minutos/horas, para reducir la ventana
de uso de un token robado), un refresh token sí se vuelve necesario: sin él,
acortar el JWT dispararía re-logins (o reautenticaciones biométricas) mucho
más seguido, degradando la experiencia. Ese es el disparador concreto para
volver a este análisis — no una fecha, sino esa decisión de seguridad.
