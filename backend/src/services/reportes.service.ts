import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { asegurarAccesoObra } from "../utils/accesoObra";
import { enteroDesdeDecimal, numeroDesdeDecimal } from "../utils/decimal";
import { esFechaISOValida } from "../utils/validacion";
import { AuthTokenPayload } from "../types/auth";

// ---------------------------------------------------------------------
// Todas las rutas de este service son de solo lectura: nunca aceptan
// escritura, solo arman consultas a partir de las tablas/vistas.
// ---------------------------------------------------------------------

export interface FilaConcentradoCargas {
  carga_id: string;
  fecha: Date;
  responsable: string;
  vehiculo_descripcion: string;
  placa: string;
  tipo_unidad: string;
  km: number | null;
  litros: number;
  rendimiento_km_l: number | null;
  horas_actual: number | null;
  horas_anterior: number | null;
  rendimiento_l_h: number | null;
  precio_por_litro: number;
  tipo_combustible: string;
  importe: number;
  foto_ticket_url: string | null;
  alerta_rendimiento: string | null;
}

export async function concentradoCargas(
  user: AuthTokenPayload,
  obraId: string,
  desde?: unknown,
  hasta?: unknown
): Promise<FilaConcentradoCargas[]> {
  asegurarAccesoObra(user, obraId);

  if (desde !== undefined && !esFechaISOValida(desde)) {
    throw new AppError(400, "desde debe ser una fecha válida.");
  }
  if (hasta !== undefined && !esFechaISOValida(hasta)) {
    throw new AppError(400, "hasta debe ser una fecha válida.");
  }

  // La vista `vista_concentrado_cargas` no expone obra_id (solo el nombre de
  // la obra), así que para filtrar de forma segura por obra se consulta
  // `cargas` directamente con sus relaciones, en vez de la vista.
  const cargas = await prisma.carga.findMany({
    where: {
      obraId,
      fechaCarga: {
        gte: desde ? new Date(desde as string) : undefined,
        lte: hasta ? new Date(hasta as string) : undefined,
      },
    },
    include: { vehiculo: true, chofer: true },
    orderBy: { fechaCarga: "desc" },
  });

  return cargas.map((c) => ({
    carga_id: c.id,
    fecha: c.fechaCarga,
    responsable: c.chofer.nombreCompleto,
    vehiculo_descripcion: `${c.vehiculo.marca} ${c.vehiculo.modelo}`,
    placa: c.vehiculo.placa,
    tipo_unidad: c.vehiculo.tipoUnidad,
    km: enteroDesdeDecimal(c.kmActual),
    litros: numeroDesdeDecimal(c.litros) ?? 0,
    rendimiento_km_l: numeroDesdeDecimal(c.rendimientoKmL),
    // Maquinaria se comprueba por horas de operación, no por km (ver
    // tipo_unidad en vehiculos): estos tres campos vienen null en cargas de
    // vehículo normal y con valor en cargas de maquinaria.
    horas_actual: numeroDesdeDecimal(c.horasActual),
    horas_anterior: numeroDesdeDecimal(c.horasAnterior),
    rendimiento_l_h: numeroDesdeDecimal(c.rendimientoLH),
    precio_por_litro: numeroDesdeDecimal(c.precioPorLitro) ?? 0,
    tipo_combustible: c.vehiculo.tipoCombustible,
    importe: numeroDesdeDecimal(c.montoTotal) ?? 0,
    foto_ticket_url: c.fotoTicketUrl,
    alerta_rendimiento: c.alertaRendimiento,
  }));
}

export interface FilaResumenFinanciero {
  semana_id: string;
  numero_semana: number;
  periodo_inicio: Date;
  periodo_fin: Date;
  solicitado: number;
  consumo: number;
  deposito: number;
  saldo_a_favor: number;
  estatus: string;
}

export async function resumenFinancieroSemanal(
  user: AuthTokenPayload,
  obraId: string
): Promise<FilaResumenFinanciero[]> {
  asegurarAccesoObra(user, obraId);
  const filas = await prisma.vistaResumenFinancieroSemanal.findMany({
    where: { obraId },
    orderBy: { periodoInicio: "desc" },
  });
  return filas.map((f) => ({
    semana_id: f.semanaId,
    numero_semana: f.numeroSemana,
    periodo_inicio: f.periodoInicio,
    periodo_fin: f.periodoFin,
    solicitado: numeroDesdeDecimal(f.solicitado) ?? 0,
    consumo: numeroDesdeDecimal(f.consumo) ?? 0,
    deposito: numeroDesdeDecimal(f.deposito) ?? 0,
    saldo_a_favor: numeroDesdeDecimal(f.saldoAFavor) ?? 0,
    estatus: f.estatus,
  }));
}

export async function resumenFinancieroConsolidado(): Promise<FilaResumenFinanciero[]> {
  const filas = await prisma.vistaResumenFinancieroConsolidado.findMany({
    orderBy: { periodoInicio: "desc" },
  });
  return filas.map((f) => ({
    semana_id: f.semanaId,
    numero_semana: f.numeroSemana,
    periodo_inicio: f.periodoInicio,
    periodo_fin: f.periodoFin,
    solicitado: numeroDesdeDecimal(f.solicitado) ?? 0,
    consumo: numeroDesdeDecimal(f.consumo) ?? 0,
    deposito: numeroDesdeDecimal(f.deposito) ?? 0,
    saldo_a_favor: numeroDesdeDecimal(f.saldoAFavor) ?? 0,
    estatus: f.estatus,
  }));
}

export interface FilaConsumoVehiculoSemanal {
  vehiculo_id: string;
  litros_consumidos: number;
  tope_litros_semanal: number;
}

export async function consumoSemanalDeVehiculo(
  user: AuthTokenPayload,
  vehiculoId: string
): Promise<FilaConsumoVehiculoSemanal> {
  const vehiculo = await prisma.vehiculo.findUnique({ where: { id: vehiculoId } });
  if (!vehiculo) {
    throw new AppError(404, "Vehículo no encontrado.");
  }
  asegurarAccesoObra(user, vehiculo.obraId);

  const fila = await prisma.vistaConsumoVehiculoSemanal.findFirst({
    where: { vehiculoId },
    orderBy: { semanaInicio: "desc" },
  });

  return {
    vehiculo_id: vehiculoId,
    litros_consumidos: fila ? numeroDesdeDecimal(fila.litrosConsumidos) ?? 0 : 0,
    tope_litros_semanal: numeroDesdeDecimal(vehiculo.topeLitrosSemanal) ?? 0,
  };
}

export interface FilaFondoSemanal {
  id: string;
  obra_id: string | null;
  numero_semana: number;
  periodo_inicio: Date;
  periodo_fin: Date;
  monto_solicitado: number;
  monto_depositado: number;
  saldo_a_favor_anterior: number;
  consumo: number;
  saldo_a_favor: number;
  estatus: string;
}

/**
 * Expone `fondo_semanal` por obra (tabla real, capturada a mano por
 * finanzas) — no la vista `vista_resumen_financiero_semanal`, que también
 * existe pero está pensada para el histórico de semanas ya cerradas. Aquí se
 * incluye la semana abierta actual, que es la que necesita
 * bandeja_autorizaciones_page.dart para mostrar el presupuesto vigente.
 *
 * saldo_a_favor se calcula con la misma fórmula que las vistas de resumen
 * financiero (ver migracion_grupo_indi.sql, sección 9):
 *   monto_depositado + saldo_a_favor_anterior - consumo_real_de_la_semana
 * El consumo real sale de `vista_consumo_semanal_por_obra` (suma de
 * `cargas.monto_total` de esa obra en esa semana), no de monto_solicitado.
 */
export async function fondoSemanalPorObra(
  user: AuthTokenPayload,
  obraId: string
): Promise<FilaFondoSemanal[]> {
  asegurarAccesoObra(user, obraId);

  const filas = await prisma.fondoSemanal.findMany({
    where: { obraId },
    orderBy: { periodoInicio: "desc" },
  });

  const consumos = await prisma.vistaConsumoSemanalPorObra.findMany({
    where: { obraId },
  });
  const consumoPorSemana = new Map<string, number>(
    consumos.map((c) => [c.semanaInicio.toISOString(), numeroDesdeDecimal(c.consumoTotal) ?? 0])
  );

  return filas.map((f) => {
    const montoSolicitado = numeroDesdeDecimal(f.montoSolicitado) ?? 0;
    const montoDepositado = numeroDesdeDecimal(f.montoDepositado) ?? 0;
    const saldoAFavorAnterior = numeroDesdeDecimal(f.saldoAFavorAnterior) ?? 0;
    const consumo = consumoPorSemana.get(f.periodoInicio.toISOString()) ?? 0;

    return {
      id: f.id,
      obra_id: f.obraId,
      numero_semana: f.numeroSemana,
      periodo_inicio: f.periodoInicio,
      periodo_fin: f.periodoFin,
      monto_solicitado: montoSolicitado,
      monto_depositado: montoDepositado,
      saldo_a_favor_anterior: saldoAFavorAnterior,
      consumo,
      saldo_a_favor: montoDepositado + saldoAFavorAnterior - consumo,
      estatus: f.estatus,
    };
  });
}
