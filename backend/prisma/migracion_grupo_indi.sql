-- =====================================================================
-- GRUPO INDI · App de Control de Flota y Cargas de Combustible
-- Script de migración inicial (PostgreSQL puro — backend en Node.js/TypeScript)
-- Incluye: esquema, vistas de reportes y datos semilla.
-- El control de acceso por rol/obra se maneja en los middlewares de Express
-- (auth.middleware.ts + role.middleware.ts), no en la base de datos.
-- =====================================================================
-- Cómo correrlo:
--   psql "postgresql://usuario:password@host:puerto/basededatos" -f migracion_grupo_indi.sql
--   o pegarlo directo en el cliente SQL de Railway/Render.
-- Después de correrlo: npx prisma db pull && npx prisma generate
-- =====================================================================
-- Nota de mantenimiento (2026-07-10): las 4 vistas que dependían de la
-- tabla "cargas" (vista_consumo_semanal_por_obra, vista_consumo_semanal_global,
-- vista_resumen_financiero_semanal, vista_resumen_financiero_consolidado)
-- estaban ubicadas en la sección 6.1, antes de que "cargas" se creara en la
-- sección 8 — el script fallaba con "relation cargas does not exist" al
-- correrlo de punta a punta. Se movieron a la sección 9, junto con las demás
-- vistas de reportes, sin modificar su contenido. Verificado: el esquema
-- resultante es idéntico al que corre en Railway (hayabusa.proxy.rlwy.net).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. EXTENSIONES NECESARIAS
-- ---------------------------------------------------------------------
create extension if not exists "uuid-ossp";

-- ---------------------------------------------------------------------
-- 1. TIPOS ENUM (evitan strings sueltos y typos en toda la app)
-- ---------------------------------------------------------------------
-- Tres roles, para coincidir con lo ya construido en frontend:
-- 'chofer', 'administrativo' (por obra) y 'finanzas' (consolidado, todas las obras).
create type rol_usuario as enum ('chofer', 'administrativo', 'finanzas');
create type estado_obra as enum ('activa', 'pausada', 'cerrada');
create type estado_vehiculo as enum ('activo', 'taller', 'baja');
create type estado_solicitud as enum ('pendiente', 'autorizado', 'rechazado', 'cargado');
create type alerta_rendimiento_tipo as enum ('bajo', 'normal', 'revisar');
create type estado_semana as enum ('abierta', 'cerrada');
create type tipo_combustible as enum ('magna', 'premium', 'diesel');
create type estado_fondo as enum ('solicitado', 'pagado');
create type tipo_unidad as enum ('vehiculo', 'maquinaria');

-- ---------------------------------------------------------------------
-- 2. OBRAS (proyectos / sitios de construcción)
-- ---------------------------------------------------------------------
create table obras (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null,
  ubicacion text,
  estado estado_obra not null default 'activa',
  fecha_inicio date not null default current_date,
  fecha_fin date,
  creado_en timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. PERFILES (usuarios: chofer / administrativo / finanzas)
--    auth_user_id: identificador estable expuesto al frontend (Perfil.authUserId),
--    ya no referencia una tabla externa de Supabase Auth — el login y las
--    contraseñas ahora los maneja este mismo backend (ver password_hash).
-- ---------------------------------------------------------------------
-- Nota de mantenimiento (2026-07-14): se agregaron correo (unique, nullable)
-- y edad (nullable) — antes ambos vivían concatenados como texto libre dentro
-- de area en los perfiles autoregistrados (POST /auth/registro-chofer, ver
-- auth.service.ts#registrarChofer), sin poder consultarse ni validarse por
-- separado. correo se normaliza a minúsculas antes de guardar (el unique
-- constraint es case-sensitive a nivel de Postgres, así que sin esto
-- "Juan@x.com" y "juan@x.com" no chocarían entre sí pese a ser el mismo
-- correo). Los registros existentes con datos en area no se migraron
-- automáticamente (ver PRUEBAS.md / backfill puntual documentado aparte).
-- (ALTER TABLE perfiles ADD COLUMN correo varchar(200) UNIQUE;
--  ALTER TABLE perfiles ADD COLUMN edad integer;)
create table perfiles (
  id uuid primary key default uuid_generate_v4(),
  auth_user_id uuid unique not null default uuid_generate_v4(),
  numero_empleado text unique not null,
  password_hash text not null,  -- bcrypt, generado por el backend (auth.routes.ts)
  nombre_completo text not null,
  rol rol_usuario not null,
  obra_id uuid references obras(id),  -- obra asignada (null para 'finanzas', que ve todas)
  vehiculo_id uuid,  -- vehículo asignado por defecto (solo aplica a choferes); FK se agrega tras crear vehiculos
  area text,  -- departamento o función del trabajador (ej. Mantenimiento, Operaciones); distinto de la obra
  correo varchar(200) unique,  -- normalizado a minúsculas por el backend antes de guardar
  edad integer,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create index idx_perfiles_obra on perfiles(obra_id);
create index idx_perfiles_rol on perfiles(rol);

-- ---------------------------------------------------------------------
-- 4. VEHÍCULOS
-- ---------------------------------------------------------------------
create table vehiculos (
  id uuid primary key default uuid_generate_v4(),
  placa text unique not null,
  tipo_unidad tipo_unidad not null default 'vehiculo',
  marca text not null,
  modelo text not null,
  anio int,
  tipo_combustible tipo_combustible not null default 'diesel',
  tope_litros_semanal numeric(10,2) not null default 0,  -- 0 = sin tope
  obra_id uuid not null references obras(id),
  estado estado_vehiculo not null default 'activo',
  creado_en timestamptz not null default now()
);

create index idx_vehiculos_obra on vehiculos(obra_id);

-- Ahora sí se puede completar la relación de perfiles -> vehiculos (vehículo asignado por defecto al chofer)
alter table perfiles add constraint fk_perfiles_vehiculo foreign key (vehiculo_id) references vehiculos(id);
create index idx_perfiles_vehiculo on perfiles(vehiculo_id);

-- Historial de reasignación de vehículo entre obras (para reportes correctos)
create table vehiculos_historial_obra (
  id uuid primary key default uuid_generate_v4(),
  vehiculo_id uuid not null references vehiculos(id),
  obra_id uuid not null references obras(id),
  fecha_inicio timestamptz not null default now(),
  fecha_fin timestamptz  -- null = asignación vigente
);

create index idx_hist_vehiculo on vehiculos_historial_obra(vehiculo_id);

-- ---------------------------------------------------------------------
-- 5. PRECIOS DE COMBUSTIBLE (vigencia por fecha, cambia entre semanas)
-- ---------------------------------------------------------------------
create table precios_combustible (
  id uuid primary key default uuid_generate_v4(),
  tipo_combustible tipo_combustible not null,
  precio_por_litro numeric(10,2) not null,
  vigente_desde date not null,
  vigente_hasta date,  -- null = vigente hasta nuevo aviso
  creado_por uuid references perfiles(id),
  creado_en timestamptz not null default now()
);

create index idx_precios_vigencia on precios_combustible(tipo_combustible, vigente_desde);

-- ---------------------------------------------------------------------
-- 6. SEMANAS OPERATIVAS (control de cierre semanal, por obra)
-- ---------------------------------------------------------------------
create table semanas_operativas (
  id uuid primary key default uuid_generate_v4(),
  obra_id uuid not null references obras(id),
  periodo_inicio date not null,
  periodo_fin date not null,
  estado estado_semana not null default 'abierta',
  cerrada_por uuid references perfiles(id),
  cerrada_en timestamptz,
  unique (obra_id, periodo_inicio)
);

-- ---------------------------------------------------------------------
-- 6.1 FONDO SEMANAL (por obra, y también consolidado de toda la empresa)
--     obra_id null = registro consolidado (empresa); con valor = esa obra específica.
--     El consumo real se calcula sumando las cargas (tickets) correspondientes.
--     El depósito se registra manualmente por ahora.
-- ---------------------------------------------------------------------
create table fondo_semanal (
  id uuid primary key default uuid_generate_v4(),
  obra_id uuid references obras(id),  -- null = consolidado (toda la empresa)
  numero_semana int not null,
  periodo_inicio date not null,
  periodo_fin date not null,
  monto_solicitado numeric(12,2) not null default 0,
  monto_depositado numeric(12,2) not null default 0,  -- captura manual, por ahora
  saldo_a_favor_anterior numeric(12,2) not null default 0,  -- lo que sobró de la semana previa
  estatus estado_fondo not null default 'solicitado',
  elaborado_por uuid references perfiles(id),
  revisado_por uuid references perfiles(id),
  autorizado_por uuid references perfiles(id),
  capturado_por uuid references perfiles(id),
  capturado_en timestamptz not null default now(),
  unique (obra_id, periodo_inicio)
);

-- ---------------------------------------------------------------------
-- 7. SOLICITUDES DE AUTORIZACIÓN
-- ---------------------------------------------------------------------
create table solicitudes_autorizacion (
  id uuid primary key default uuid_generate_v4(),
  chofer_id uuid not null references perfiles(id),
  vehiculo_id uuid not null references vehiculos(id),
  obra_id uuid not null references obras(id),
  litros_solicitados numeric(10,2) not null,
  litros_autorizados numeric(10,2),  -- null hasta que se resuelva; puede ser menor al solicitado (autorización parcial)
  comentario text,  -- campo único (frontend no separa comentario de chofer vs motivo de admin)
  estado estado_solicitud not null default 'pendiente',
  resuelto_por uuid references perfiles(id),
  resuelto_en timestamptz,
  creado_en timestamptz not null default now(),
  creado_offline boolean not null default false,  -- viene de PowerSync sin conexión
  actividad text,  -- para qué se usará el combustible (ej. "suministro a maquinaria en tramo")
  responsable text  -- persona que reporta/autoriza en campo, distinta de resuelto_por
);

create index idx_solicitudes_obra on solicitudes_autorizacion(obra_id, estado);
create index idx_solicitudes_chofer on solicitudes_autorizacion(chofer_id);

-- ---------------------------------------------------------------------
-- 8. CARGAS (registro real de combustible cargado)
-- ---------------------------------------------------------------------
-- Nota de mantenimiento (2026-07-13): solicitud_id se volvió NOT NULL
-- (antes permitía null). crear() en carga.service.ts ya exigía solicitud_id
-- en todos los casos; no había ninguna fila con valor null en Railway al
-- aplicar el cambio (ALTER TABLE cargas ALTER COLUMN solicitud_id SET NOT NULL).
create table cargas (
  id uuid primary key default uuid_generate_v4(),
  solicitud_id uuid not null references solicitudes_autorizacion(id),
  chofer_id uuid not null references perfiles(id),
  vehiculo_id uuid not null references vehiculos(id),
  obra_id uuid not null references obras(id),
  litros numeric(10,2) not null,
  precio_por_litro numeric(10,2) not null,
  monto_total numeric(10,2) generated always as (litros * precio_por_litro) stored,
  km_actual numeric(10,1),
  km_anterior numeric(10,1),
  horas_actual numeric(10,1),   -- para maquinaria (horómetro), alternativa a km
  horas_anterior numeric(10,1),
  rendimiento_km_l numeric(10,2),  -- calculado en Edge Function al insertar (vehículo)
  rendimiento_l_h numeric(10,2),   -- calculado en Edge Function al insertar (maquinaria)
  alerta_rendimiento alerta_rendimiento_tipo,  -- null = no aplica (ej. equipo menor sin medición)
  foto_ticket_url text,
  -- Nota de mantenimiento (2026-07-14): "¿se alcanza a leer el número en la
  -- foto?" — una sola respuesta por carga (ticket único o evidencia
  -- múltiple, ver carga_evidencias más abajo), no por foto.
  evidencia_legible boolean,
  fecha_carga timestamptz not null default now(),
  creado_offline boolean not null default false,
  sincronizado_en timestamptz
);

-- Fotos de evidencia múltiple (Maquinaria) — complementa foto_ticket_url
-- (Carga, foto única, caso Vehículo). Antes de esto, comprobar_carga_page.dart
-- solo podía subir la primera foto de evidencia; el resto se perdían porque
-- no existía dónde guardarlas.
create table carga_evidencias (
  id uuid primary key default uuid_generate_v4(),
  carga_id uuid not null references cargas(id),
  foto_url text not null,
  orden integer not null default 0,
  creado_en timestamptz not null default now()
);

create index idx_carga_evidencias_carga on carga_evidencias(carga_id);

create index idx_cargas_obra_fecha on cargas(obra_id, fecha_carga);
create index idx_cargas_vehiculo on cargas(vehiculo_id, fecha_carga);
create index idx_cargas_chofer on cargas(chofer_id);

-- ---------------------------------------------------------------------
-- 9. VISTAS DE REPORTES
-- ---------------------------------------------------------------------

-- Consumo real de la semana, por obra
create view vista_consumo_semanal_por_obra as
select
  c.obra_id,
  date_trunc('week', c.fecha_carga)::date as semana_inicio,
  sum(c.monto_total) as consumo_total
from cargas c
group by c.obra_id, date_trunc('week', c.fecha_carga);

-- Consumo real de la semana, a nivel empresa (para el consolidado)
create view vista_consumo_semanal_global as
select
  date_trunc('week', c.fecha_carga)::date as semana_inicio,
  sum(c.monto_total) as consumo_total,
  count(c.id) as total_cargas
from cargas c
group by date_trunc('week', c.fecha_carga);

-- Vista para ReportesRepository.resumenFinancieroSemanal(obraId) — coincide con VistaResumenFinancieroSemanal
create view vista_resumen_financiero_semanal as
select
  f.id as semana_id,
  f.numero_semana,
  f.obra_id,
  f.periodo_inicio,
  f.periodo_fin,
  f.monto_solicitado as solicitado,
  coalesce(v.consumo_total, 0) as consumo,
  f.monto_depositado as deposito,
  (f.monto_depositado + f.saldo_a_favor_anterior - coalesce(v.consumo_total, 0)) as saldo_a_favor,
  f.estatus::text as estatus
from fondo_semanal f
left join vista_consumo_semanal_por_obra v
  on v.obra_id = f.obra_id and v.semana_inicio = f.periodo_inicio
where f.obra_id is not null;

-- Vista para ReportesRepository.resumenFinancieroConsolidado() — mismo formato, para toda la empresa
create view vista_resumen_financiero_consolidado as
select
  f.id as semana_id,
  f.numero_semana,
  f.periodo_inicio,
  f.periodo_fin,
  f.monto_solicitado as solicitado,
  coalesce(v.consumo_total, 0) as consumo,
  f.monto_depositado as deposito,
  (f.monto_depositado + f.saldo_a_favor_anterior - coalesce(v.consumo_total, 0)) as saldo_a_favor,
  f.estatus::text as estatus
from fondo_semanal f
left join vista_consumo_semanal_global v on v.semana_inicio = f.periodo_inicio
where f.obra_id is null;

-- 9.1 Concentrado de cargas: detalle por carga con datos de contexto
create view vista_concentrado_cargas as
select
  c.id,
  o.nombre as obra,
  p.nombre_completo as chofer,
  (v.marca || ' ' || v.modelo) as vehiculo,
  v.placa,
  v.tipo_unidad,
  c.km_actual,
  c.horas_actual,
  c.litros,
  c.rendimiento_km_l,
  c.rendimiento_l_h,
  c.precio_por_litro,
  v.tipo_combustible,
  c.monto_total,
  c.alerta_rendimiento,
  c.fecha_carga,
  c.foto_ticket_url
from cargas c
join obras o on o.id = c.obra_id
join vehiculos v on v.id = c.vehiculo_id
join perfiles p on p.id = c.chofer_id;

-- 9.2 Función flexible: resumen de cargas por día, semana, mes o año (para el Segmentador de periodo)
-- Uso: select * from resumen_financiero_por_periodo('mes', '2026-01-01', '2026-12-31');
create or replace function resumen_financiero_por_periodo(
  periodo text,        -- 'day' | 'week' | 'month' | 'year'
  fecha_desde date,
  fecha_hasta date
)
returns table (
  obra_id uuid,
  obra text,
  periodo_inicio date,
  total_cargas bigint,
  total_litros numeric,
  total_gastado numeric
) as $$
begin
  return query
  select
    o.id,
    o.nombre,
    date_trunc(periodo, c.fecha_carga)::date,
    count(c.id),
    sum(c.litros),
    sum(c.monto_total)
  from cargas c
  join obras o on o.id = c.obra_id
  where c.fecha_carga::date between fecha_desde and fecha_hasta
  group by o.id, o.nombre, date_trunc(periodo, c.fecha_carga);
end;
$$ language plpgsql stable;

-- 9.3 Consumo por vehículo (para validar tope semanal)
create view vista_consumo_vehiculo_semanal as
select
  v.id as vehiculo_id,
  v.placa,
  v.tope_litros_semanal,
  date_trunc('week', c.fecha_carga)::date as semana_inicio,
  sum(c.litros) as litros_consumidos
from cargas c
join vehiculos v on v.id = c.vehiculo_id
group by v.id, v.placa, v.tope_litros_semanal, date_trunc('week', c.fecha_carga);

-- ---------------------------------------------------------------------
-- 10. CONTROL DE ACCESO (ya NO vive aquí)
-- ---------------------------------------------------------------------
-- Con Supabase se usaba Row Level Security (RLS) directamente en Postgres.
-- Con el backend en Node.js/Express, el control de acceso por rol y por obra
-- se implementa en los middlewares, no en la base de datos:
--
--   src/middlewares/auth.middleware.ts   → valida el JWT, adjunta req.user = { id, rol, obraId }
--   src/middlewares/role.middleware.ts   → valida que req.user.rol tenga permiso para la ruta
--
-- Reglas que antes eran políticas RLS y ahora se validan en cada controller:
--   - chofer: solo ve/crea sus propias solicitudes y cargas (where chofer_id = req.user.id)
--   - administrativo: solo ve/resuelve lo de su obra (where obra_id = req.user.obraId)
--   - finanzas: sin restricción de obra_id (ve y administra todo, incluido fondo_semanal consolidado)
--
-- La base de datos queda sin RLS habilitado; toda la seguridad de acceso
-- depende de que cada endpoint de Express aplique estos filtros correctamente.

-- ---------------------------------------------------------------------
-- 11. DATOS SEMILLA (para desarrollo y pruebas)
-- ---------------------------------------------------------------------

-- 11.1 Obras
insert into obras (id, nombre, ubicacion, estado, fecha_inicio) values
  ('a1000000-0000-0000-0000-000000000001', 'Obra Residencial Los Pinos', 'Monterrey, NL', 'activa', '2026-01-15'),
  ('a1000000-0000-0000-0000-000000000002', 'Obra Plaza Comercial Norte', 'Saltillo, COAH', 'activa', '2026-03-01');

-- 11.2 Vehículos y maquinaria (todos con placa, marca y modelo, según requiere el frontend)
insert into vehiculos (id, placa, tipo_unidad, marca, modelo, anio, tipo_combustible, tope_litros_semanal, obra_id, estado) values
  ('b2000000-0000-0000-0000-000000000001', 'INDI-001', 'vehiculo', 'Ford', 'F-150', 2022, 'diesel', 300, 'a1000000-0000-0000-0000-000000000001', 'activo'),
  ('b2000000-0000-0000-0000-000000000002', 'INDI-002', 'vehiculo', 'Chevrolet', 'Silverado', 2021, 'diesel', 300, 'a1000000-0000-0000-0000-000000000001', 'activo'),
  ('b2000000-0000-0000-0000-000000000003', 'INDI-003', 'vehiculo', 'Nissan', 'NP300', 2023, 'magna', 200, 'a1000000-0000-0000-0000-000000000002', 'activo'),
  ('b2000000-0000-0000-0000-000000000005', 'INDI-MAQ-01', 'maquinaria', 'Caterpillar', 'Excavadora 320', 2020, 'diesel', 0, 'a1000000-0000-0000-0000-000000000001', 'activo');

-- 11.3 Precio de combustible vigente
insert into precios_combustible (tipo_combustible, precio_por_litro, vigente_desde) values
  ('diesel', 24.50, '2026-01-01'),
  ('magna', 23.99, '2026-01-01'),
  ('premium', 25.79, '2026-01-01');

-- 11.4 Semana operativa actual (ejemplo, por obra)
insert into semanas_operativas (obra_id, periodo_inicio, periodo_fin, estado) values
  ('a1000000-0000-0000-0000-000000000001', '2026-07-06', '2026-07-12', 'abierta'),
  ('a1000000-0000-0000-0000-000000000002', '2026-07-06', '2026-07-12', 'abierta');

-- 11.5 Fondo semanal: registros por obra + un registro consolidado (obra_id null) por semana
insert into fondo_semanal (obra_id, numero_semana, periodo_inicio, periodo_fin, monto_solicitado, monto_depositado, saldo_a_favor_anterior, estatus) values
  ('a1000000-0000-0000-0000-000000000001', 27, '2026-06-29', '2026-07-05', 150000, 150000, 0, 'pagado'),
  ('a1000000-0000-0000-0000-000000000002', 27, '2026-06-29', '2026-07-05', 60000, 60000, 0, 'pagado'),
  (null, 27, '2026-06-29', '2026-07-05', 210000, 210000, 0, 'pagado'),
  ('a1000000-0000-0000-0000-000000000001', 28, '2026-07-06', '2026-07-12', 160000, 0, 8000, 'solicitado'),
  ('a1000000-0000-0000-0000-000000000002', 28, '2026-07-06', '2026-07-12', 60000, 0, 3500, 'solicitado'),
  (null, 28, '2026-07-06', '2026-07-12', 220000, 0, 11500, 'solicitado');

-- NOTA: la contraseña de cada perfil se guarda como hash bcrypt (password_hash),
-- generado por el backend (ver auth.routes.ts / script de seed en Node) — nunca
-- se inserta la contraseña en texto plano directamente por SQL. Ejemplo de shape
-- una vez generado el hash desde Node (bcrypt.hashSync('la-contraseña', 10)):
--
-- insert into perfiles (numero_empleado, password_hash, nombre_completo, rol, obra_id, vehiculo_id) values
--   ('EMP-1001', '<hash-bcrypt>', 'Juan Pérez', 'chofer', 'a1000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001'),
--   ('EMP-2001', '<hash-bcrypt>', 'María López', 'administrativo', 'a1000000-0000-0000-0000-000000000001', null),
--   ('EMP-3001', '<hash-bcrypt>', 'Carlos Ruiz', 'finanzas', null, null);

-- =====================================================================
-- FIN DEL SCRIPT
-- =====================================================================
