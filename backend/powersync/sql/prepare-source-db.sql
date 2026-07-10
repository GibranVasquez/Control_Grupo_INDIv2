-- Prepara gi_control_combustible como fuente de replicación lógica para
-- PowerSync. Requiere un rol superusuario de Postgres (localmente: `psql -U
-- postgres`). Ya se ejecutó una vez en este entorno de desarrollo (ver
-- POWERSYNC.md); este archivo queda como referencia reproducible para otros
-- entornos (staging, la máquina de otro dev, etc).
--
-- El cambio de wal_level (paso 1) requiere reiniciar el servicio de Postgres
-- para tener efecto — NO se aplica solo con este script.

-- 1) Habilitar replicación lógica (requiere reinicio de Postgres después).
ALTER SYSTEM SET wal_level = logical;

-- 2) Rol dedicado para PowerSync: solo lectura + permiso de replicación.
--    Nunca reutilizar el rol de la app (gi_app) para esto.
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'powersync_role') THEN
    CREATE ROLE powersync_role WITH REPLICATION LOGIN PASSWORD 'CAMBIA-ESTA-PASSWORD';
  ELSE
    ALTER ROLE powersync_role WITH REPLICATION LOGIN PASSWORD 'CAMBIA-ESTA-PASSWORD';
  END IF;
END
$$;

\connect gi_control_combustible

GRANT SELECT ON ALL TABLES IN SCHEMA public TO powersync_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO powersync_role;

-- 3) Publicación lógica que PowerSync replica. El nombre "powersync" es fijo
--    (lo espera el servicio). FOR ALL TABLES es suficiente para este tamaño
--    de base; si crece mucho, cambiar a FOR TABLE listando explícitamente
--    las tablas de negocio (obras, perfiles, vehiculos, cargas,
--    solicitudes_autorizacion, precios_combustible, etc — no hace falta
--    incluir las vistas vista_*, que no son tablas base).
CREATE PUBLICATION powersync FOR ALL TABLES;
