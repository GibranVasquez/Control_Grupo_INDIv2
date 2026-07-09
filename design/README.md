# Handoff: INDI Combustible — App de control de combustible en obra

## Overview
Aplicación para digitalizar el proceso de solicitud, autorización y comprobación de cargas de combustible de la flota de Grupo INDI (Obra: Tren Golfo de México). Hoy el proceso se hace por WhatsApp + dos hojas de Excel (Concentrado de cargas y Resumen financiero). La app sustituye ese flujo con:

1. **App móvil del chofer** — inicia sesión, solicita litros para el día siguiente, recibe la autorización y comprueba la carga con foto del ticket.
2. **Panel de administración (web + móvil)** — el autorizador aprueba/ajusta solicitudes con reglas; el administrador ve el concentrado de cargas y el resumen financiero, ambos alimentados automáticamente.

**Flujo end-to-end:** Login → Solicita litros → Admin autoriza (total o menos + motivo) → Chofer carga y sube ticket + datos del viaje → se llena el Concentrado → se actualiza el Resumen financiero.

## About the Design Files
Los archivos de este paquete son **referencias de diseño creadas en HTML** — un prototipo que muestra la apariencia y el comportamiento buscados, **no código de producción para copiar tal cual**. `Combustible INDI.dc.html` usa un runtime propietario de prototipado (`support.js`, etiquetas `<x-dc>`, `<sc-if>`, `{{ }}`); **no lo lleves a producción**.

La tarea es **recrear estos diseños en Flutter** (ver stack destino abajo) siguiendo buenas prácticas del framework. Abre el HTML en un navegador para ver el diseño renderizado y como fuente de medidas/colores exactos, y apóyate en las capturas de la carpeta `screenshots/`.

## Fidelity
**Alta fidelidad (hi-fi).** Colores, tipografía, espaciados e interacciones son definitivos. Recrea la UI pixel-perfect. Los datos mostrados son de ejemplo (basados en las hojas reales del cliente).

## Target stack — Flutter (VS Code)
Este proyecto se programará en **Flutter** usando **Visual Studio Code**.

- **Una sola base de código Flutter** para la app del chofer (móvil) y el panel admin (usa layouts responsivos con `LayoutBuilder` / `MediaQuery`: móvil para el chofer, ancho/tablet-desktop para el panel — Flutter Web o desktop para el admin).
- **Setup:** instala la extensión *Flutter* + *Dart* en VS Code. `flutter create indi_combustible`. Corre con F5 (debug) o `flutter run -d chrome` para el panel web.
- **Arquitectura sugerida:** gestión de estado con **Riverpod** (o Provider/Bloc si el equipo prefiere). Navegación con **go_router**. Modelos inmutables con **freezed** + serialización **json_serializable**.
- **Paquetes recomendados:**
  - `google_fonts` → Manrope (UI) e IBM Plex Mono (números/datos).
  - `image_picker` o `camera` → foto del ticket de gasolinería.
  - `intl` → formato de moneda `es_MX` y fechas (`NumberFormat.currency(locale:'es_MX', symbol:'\$')`).
  - `data_table_2` o `Table`/`DataTable` nativo → Concentrado y Finanzas.
  - `fl_chart` (opcional) → barra de presupuesto / gráficos.
  - `flutter_secure_storage` → token de sesión.
  - `http`/`dio` → API. `firebase_auth` o `openid_client` → login nº empleado + SSO corporativo.
- **Mapa de widgets (referencia rápida):**
  - Pantallas → `Scaffold` con `body` en `Column`/`ListView`.
  - Tarjetas → `Container` con `BoxDecoration` (`borderRadius`, `border`, `boxShadow`).
  - Steppers −/+ → `Row` con `IconButton`/`InkWell` de 60×60 (móvil) o 40×40.
  - Chips de combustible → `ToggleButtons` o `ChoiceChip`.
  - Slider de autorización → `Slider` (`divisions` para el paso de 5).
  - Badges de estatus → `Container` con `BoxDecoration(borderRadius: BorderRadius.circular(20))`.
  - Sidebar admin → `NavigationRail` o `Drawer` fijo.
  - Gradientes → `LinearGradient` en `BoxDecoration`.
- Define un `ThemeData` central con los tokens de color/tipografía de la sección **Design Tokens** para no repetir literales.
- **Backend:** API REST + base de datos (p.ej. Postgres/Firebase). Imágenes de tickets en almacenamiento de objetos (S3/GCS/Firebase Storage). Auth con nº de empleado + contraseña y SSO corporativo (OIDC/SAML).

---

## Screens / Views

### App del chofer (móvil — ancho de diseño 340px de contenido, pantallas 710px alto de bezel)

#### 1. Login
- **Purpose:** El chofer entra a la app.
- **Layout:** Columna. Bloque de marca superior (gradiente azul, padding 40px 26px 34px) con logo INDI (66×66, radius 17px), título "INDI Combustible" (24px/800), tagline "Control de combustible en obra" (14.5px, opacidad .85). Debajo, formulario en fondo blanco (padding 26px 24px).
- **Components:**
  - Campo "NÚMERO DE EMPLEADO": label 13px/800 color #5A6B86; input fondo #F4F6FA, borde 1.5px #E2E7F0, radius 14px, padding 16px, fuente mono 19px. Valor ejemplo `INDI-04871`.
  - Campo "CONTRASEÑA": mismo estilo, muestra `••••••` 22px con enlace "Ver" (#0165F9). Debajo, "¿Olvidaste tu contraseña?" alineado a la derecha (#0165F9, 13.5px/700).
  - Botón primario "Ingresar": full-width, fondo #0165F9, texto blanco 18px/800, radius 15px, padding 18px, sombra `0 12px 26px -10px rgba(1,101,249,.65)`.
  - Divisor "o" (línea #E2E7F0 + texto #9AA4B4).
  - Botón secundario "Acceso corporativo INDI" (SSO): fondo blanco, borde 1.5px #DCE3EE, texto #0A1E44 15.5px/800, radius 15px, con mini-logo 22×22. Este es el **segundo método de acceso** (SSO / OIDC-SAML).
  - Pie: "Grupo INDI © 2026 · v1.0" (12.5px, #9AA4B4).

#### 2. Inicio / Mis solicitudes
- **Purpose:** Ver estado de solicitudes y arrancar una nueva.
- **Layout:** Header azul (gradiente) con status bar de marca (logo + "Combustible"), saludo "Buen día, Germán Hernández" (22px/800) y avatar circular con iniciales. Tarjeta "Mi vehículo" translúcida dentro del header. Cuerpo en fondo #F4F6FA.
- **Components:**
  - Botón grande "⛽ Solicitar litros para mañana" (#0165F9, 18px/800, radius 16px, padding 20px).
  - Lista "MIS SOLICITUDES": tarjetas blancas (radius 16px, borde #E4E9F2, sombra suave) con fecha (16px/800), badge de estatus y detalle (15px, #5A6B86).
  - **Badges de estatus:** AUTORIZADO `bg #E7F6F0 / text #0E9F6E`; EN ESPERA `bg #FEF3E0 / text #C77C0A`; CARGADO `bg #EAF1FF / text #0165F9`.

#### 3. Solicitar litros
- **Purpose:** Crear solicitud para el día siguiente.
- **Components:**
  - "PARA EL DÍA": campo de solo lectura (fecha del día siguiente).
  - Selector de combustible: 3 chips (Magna / Premium / Diésel). Chip activo #0165F9 blanco; inactivos blancos borde #E4E9F2 texto #5A6B86.
  - Stepper de litros: botones −/+ de 60×60 (fondo #EAF1FF, glifo #0165F9 34px), número central mono 44px. Rango 5–60, paso 5 (tope por vehículo).
  - Texto "Cuesta aprox. $X" (importe = litros × costo/L).
  - Campo opcional "¿POR QUÉ?" (motivo).
  - Botón "Enviar solicitud" (barra inferior fija).

#### 4. Respuesta del admin (autorización recibida)
- **Purpose:** El chofer ve si le autorizaron total o menos y el motivo.
- **Components:**
  - Ícono de éxito circular (82×82, bg #E7F6F0, check #0E9F6E), título "¡Autorizado!", subtítulo "por Ing. …".
  - Tarjeta resumen: "Solicitaste 40 L" / "Te autorizaron 35 L" (número grande 26px verde #0E9F6E).
  - Bloque MOTIVO (bg #FEF3E0, borde #F5D9A8, texto #7A5410) — visible cuando autorizan menos.
  - Botón "✓ Ya cargué · comprobar".

#### 5. Comprobar carga + ticket
- **Purpose:** Registrar la carga real y subir foto del ticket.
- **Components:**
  - **Tarjeta "DATOS DEL VEHÍCULO"** (bg navy #0A1E44, texto blanco): Responsable, Modelo, Placas (mono). Sirve para que el admin identifique la unidad.
  - Zona de foto del ticket: recuadro dashed (borde #B7C4D9), ícono cámara en cuadro #0165F9, texto "Tomar foto del ticket". **Usar la cámara del teléfono.**
  - Steppers "KM DEL DÍA" y "LITROS" (botones −/+ 40×40, valores mono).
  - Tarjeta RENDIMIENTO: `km/L` calculado + badge (Normal / Bajo / ⚠ Revisar).
  - Desglose: Costo x litro ($23.99), Importe (grande #0165F9), Gasolinería.
  - Botón "Enviar comprobación".

### Panel de administración (web — ventanas de navegador, anchos 1080–1120px)

Todas las ventanas comparten chrome de navegador (barra #0E1526, tres puntos de semáforo, URL mono `combustible.grupoindi.mx/...`).

#### 6. Bandeja de autorizaciones
- **Layout:** Sidebar navy #0A1E44 (210px) con logo + nav (🔔 Autorizaciones activo #0165F9, 📋 Concentrado, 💲 Finanzas, 🚚 Vehículos, 👥 Choferes, usuario al pie). Contenido central (lista de solicitudes) + panel derecho de reglas (270px, bg #F4F6FA).
- **Solicitud expandida (card borde 1.5px #0165F9):** avatar iniciales, nombre 16px/800, línea mono "Modelo · Placas · Combustible", badge PENDIENTE. Tres mini-cards: SOLICITADO / TOPE VEHÍCULO / PRESUP. SEMANA. Slider "AUTORIZAR" (0–60, paso 5). **Regla:** si el valor autorizado < solicitado, aparece bloque rojo "⚠ COMENTARIO OBLIGATORIO" con textarea. Botones "Autorizar N L" (#0165F9) y "Rechazar" (outline rojo #E11D48).
- **Solicitudes colapsadas:** filas con avatar, nombre, detalle mono y litros + chevron.
- **Panel de reglas:** tarjetas "Tope por vehículo", "Comentario obligatorio", "Límite semanal $". Card de presupuesto (gradiente azul) con barra de progreso (70% ejercido de $1,000,000).

#### 7. Concentrado de cargas
- **Purpose:** Tabla que se llena sola con cada comprobación (reemplaza la hoja de Excel 2).
- **Columnas:** FECHA, RESPONSABLE, VEHÍCULO, PLACAS, KM (der.), LITROS (der.), KM/L (der.), $/L (der.), COMB., IMPORTE (der.), TICKET.
- **Estilo tabla:** header navy #0A1E44 texto blanco 11px; cuerpo fuente mono 12.5px, nombres/combustible en Manrope; filas separadas por borde #EEF1F6.
- **Resaltados de fila:** rendimiento anómalo → `bg #FEECF0` + km/L en rojo con ⚠; ticket pendiente → `bg #FEF3E0` + "pend." en $/L naranja.
- **Footer TOTALES** (bg #EAF1FF): suma de litros e importe de la semana.
- Acciones: "Exportar Excel", "Filtros". Leyenda de colores al pie.

#### 8. Resumen financiero
- **Purpose:** Reemplaza la hoja de Excel 1 (control por responsable/semana).
- **Header:** nombre del proveedor + periodo; dos tarjetas KPI (TOTAL DEPOSITADO gradiente azul, SALDO DISPONIBLE navy).
- **Columnas:** SEMANA, PERIODO, SOLICITADO (der.), CONSUMO (der.), DEPÓSITO (der.), SALDO A FAVOR (der.), ESTATUS.
- **Badges estatus:** PAGADO `#E7F6F0/#0E9F6E`; SOLICITADO `#FEF9C3/#A16207`.
- **Footer TOTALES** (bg #EAF1FF). Pie con firmas "Elaboró / Revisó / Autorizó".

---

## Interactions & Behavior
- **Login:** validar nº empleado + contraseña; "Acceso corporativo INDI" inicia flujo SSO (OIDC/SAML). Tras login, el chofer solo ve su vehículo y sus solicitudes.
- **Solicitud (stepper):** −/+ ajustan litros en pasos de 5, límites 5..tope-del-vehículo. Importe estimado = litros × costo/L, se recalcula en vivo.
- **Autorización (slider):** 0..tope, paso 5. Si `autorizado < solicitado` ⇒ el textarea de motivo es **obligatorio** (bloquear "Autorizar" sin texto). El texto del botón refleja el valor ("Autorizar 35 L").
- **Comprobación:** foto obligatoria del ticket (cámara). km/L = km / litros. Badge: `<3` o `>15` → ⚠ Revisar (rojo); `3–6` → Bajo (naranja); `>6` → Normal (verde). Umbrales configurables.
- **Concentrado:** cada comprobación aprobada agrega una fila; recalcula totales y marca anomalías.
- **Finanzas:** consumo semanal = suma de importes de las cargas de la semana; saldo a favor acumulado = depósitos − consumos.
- **Responsive:** el chofer es móvil-first; el panel admin funciona en laptop y también en móvil del autorizador.

## State Management
- **Sesión/usuario:** id empleado, rol (chofer / autorizador / admin financiero / revisó), vehículo asignado.
- **Solicitud:** fecha, tipo combustible, litros solicitados, motivo, estatus (pendiente/autorizado/rechazado/cargado), litros autorizados, comentario del ajuste, autorizador.
- **Comprobación (carga):** litros cargados, km del día, gasolinería, folio, foto (URL), costo/L, importe, km/L calculado, flag anomalía.
- **Semana/presupuesto:** nº semana, periodo, presupuesto, ejercido, restante, solicitado, consumo, depósito, saldo a favor, estatus de pago.
- **Catálogos:** vehículos (modelo, placas, tope de litros, tipo combustible), choferes. Vehículos = catálogo fijo + captura libre.

## Design Tokens
**Colores**
- Primario (INDI azul): `#0165F9`; azul oscuro (hover): `#0148c0`; gradiente marca: `linear-gradient(160deg,#0165F9,#0a3fb0)`.
- Navy (chrome/tablas/texto marca): `#0A1E44`; tinta: `#0E1526`.
- Texto secundario: `#5A6B86` / `#64708A`; terciario/placeholder: `#9AA4B4` / `#8A94A6`.
- Fondo app: `#E7ECF4`; superficie clara: `#F4F6FA`; blanco `#FFFFFF`.
- Bordes: `#DCE3EE`, `#E4E9F2`, `#E2E7F0`, `#EEF1F6`.
- Éxito: texto `#0E9F6E` / bg `#E7F6F0`. Aviso: texto `#C77C0A` / bg `#FEF3E0`. Error: texto `#E11D48` / bg `#FEECF0` / borde `#F5B8C6`. Info: texto `#0165F9` / bg `#EAF1FF`. Amarillo estatus: `#A16207` / `#FEF9C3`.

**Tipografía**
- UI: **Manrope** (400/500/600/700/800). Números/datos: **IBM Plex Mono** (500/600).
- Escala móvil: títulos de pantalla 18px/800; encabezado saludo 22px/800; body 15–16px; labels 13px/800 uppercase; número stepper 44px mono; importe 24px mono.
- Escala web: título sección 19px/800; header tabla 11px; celdas 12.5px.

**Radios:** 44px (bezel teléfono), 34px (pantalla interior), 16–20px (cards móvil), 14px (inputs/cards web), 12px (mini-cards), 20px (badges/chips), 9–11px (botones nav).

**Sombras:** botón primario `0 12px 26px -10px rgba(1,101,249,.65)`; card móvil `0 4px 14px -10px rgba(10,30,68,.3)`; ventana web `0 24px 50px -28px rgba(10,30,68,.45)`; bezel `0 30px 60px -24px rgba(10,30,68,.5)`.

**Costo de referencia:** Magna $23.99/L, Diésel $28.00/L (ejemplo — traer de catálogo/precio del día).

## Assets
- `assets/indi-logo.jpg` — logo oficial de Grupo INDI (cuadro azul con "INDI" en blanco, 447×447). Usar como app icon, en login, header móvil, sidebar admin y reportes. Idealmente convertir a SVG/PNG con transparencia para producción.
- Emojis usados como placeholders de íconos (⛽ 📷 🔔 📋 💲 🚚 👥) — sustituir por un set de íconos del design system destino (p.ej. Lucide/Phosphor).

## Files
- `Combustible INDI.dc.html` — prototipo completo (todas las pantallas, en un lienzo). **Referencia visual**, no producción.
- `support.js` — runtime del prototipo (ignorar para producción).
- `assets/indi-logo.jpg` — logo.
- `screenshots/01-app-chofer.png` — las 5 pantallas de la app del chofer (login, inicio, solicitar, respuesta, comprobar carga).
- `screenshots/02-panel-autorizaciones.png` — bandeja de autorizaciones con sidebar y reglas.
- `screenshots/03-concentrado-cargas.png` — tabla del concentrado de cargas.
- `screenshots/04-resumen-financiero.png` — resumen financiero por semana.
