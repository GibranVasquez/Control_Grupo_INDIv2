import 'package:powersync/powersync.dart';

/// Esquema SQLite local, espejo de las 6 tablas que sí están en
/// backend/powersync/config/sync-config.yaml (`bucket_definitions`).
///
/// Nombres de tabla/columna en snake_case idénticos a Postgres: PowerSync
/// replica directo del WAL, no a través de Prisma (mismo criterio que ya
/// sigue sync-config.yaml). Los tipos numéricos (`Column.real`) reciben los
/// `NUMERIC`/`DECIMAL` de Postgres, que la vista de PowerSync entrega como
/// strings; SQLite los castea automáticamente al tipo declarado.
///
/// Deliberadamente NO están aquí `semanas_operativas`, `fondo_semanal` ni las
/// vistas de reportes (`vista_*`): ninguna está en sync-config.yaml (las
/// primeras dos no se incluyeron en el alcance original; las vistas no son
/// replicables por WAL). Esas entidades se resuelven vía API REST directa
/// (ver services/api/api_semana_operativa_repository.dart y
/// services/api/api_reportes_repository.dart).
///
final Schema powerSyncSchema = Schema([
  Table('obras', [
    Column.text('nombre'),
    Column.text('ubicacion'),
    Column.text('estado'),
    Column.text('fecha_inicio'),
    Column.text('fecha_fin'),
    Column.text('creado_en'),
  ]),
  Table('perfiles', [
    Column.text('auth_user_id'),
    Column.text('usuario'),
    Column.text('nombre_completo'),
    Column.text('rol'),
    Column.text('correo'),
    Column.integer('edad'),
    Column.text('obra_id'),
    Column.text('vehiculo_id'),
    Column.text('area'),
    Column.integer('activo'),
    Column.text('creado_en'),
  ]),
  Table('vehiculos', [
    Column.text('placa'),
    Column.text('tipo_unidad'),
    Column.text('marca'),
    Column.text('modelo'),
    Column.integer('anio'),
    Column.text('tipo_combustible'),
    Column.real('tope_litros_semanal'),
    Column.text('obra_id'),
    Column.text('estado'),
    Column.text('creado_en'),
  ]),
  Table('precios_combustible', [
    Column.text('tipo_combustible'),
    Column.real('precio_por_litro'),
    Column.text('vigente_desde'),
    Column.text('vigente_hasta'),
    Column.text('creado_por'),
    Column.text('creado_en'),
  ]),
  Table('solicitudes_autorizacion', [
    Column.text('chofer_id'),
    Column.text('vehiculo_id'),
    Column.text('obra_id'),
    Column.real('litros_solicitados'),
    Column.real('litros_autorizados'),
    Column.text('comentario'),
    Column.text('estado'),
    Column.text('resuelto_por'),
    Column.text('resuelto_en'),
    Column.text('creado_en'),
    Column.integer('creado_offline'),
    Column.text('actividad'),
    Column.text('responsable'),
  ]),
  Table('cargas', [
    Column.text('solicitud_id'),
    Column.text('chofer_id'),
    Column.text('vehiculo_id'),
    Column.text('obra_id'),
    Column.real('litros'),
    Column.real('precio_por_litro'),
    Column.real('monto_total'),
    Column.real('km_actual'),
    Column.real('km_anterior'),
    Column.real('horas_actual'),
    Column.real('horas_anterior'),
    Column.real('rendimiento_km_l'),
    Column.real('rendimiento_l_h'),
    Column.text('alerta_rendimiento'),
    Column.text('foto_ticket_url'),
    Column.integer('evidencia_legible'),
    Column.text('fecha_carga'),
    Column.integer('creado_offline'),
    Column.text('sincronizado_en'),
  ]),
]);
