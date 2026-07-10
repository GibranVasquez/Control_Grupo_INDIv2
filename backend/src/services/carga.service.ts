import { AlertaRendimientoTipo, Carga, Prisma } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { asegurarAccesoObra } from "../utils/accesoObra";
import { enteroDesdeDecimal, numeroDesdeDecimal } from "../utils/decimal";
import {
  esFechaISOValida,
  esNumeroNoNegativo,
  esNumeroPositivo,
  esStringNoVacia,
  esUuidValido,
} from "../utils/validacion";
import { AuthTokenPayload } from "../types/auth";

export interface CargaPublica {
  id: string;
  solicitud_id: string | null;
  chofer_id: string;
  vehiculo_id: string;
  obra_id: string;
  litros: number;
  precio_por_litro: number;
  monto_total: number;
  km_actual: number | null;
  km_anterior: number | null;
  rendimiento_km_l: number | null;
  horas_actual: number | null;
  horas_anterior: number | null;
  rendimiento_l_h: number | null;
  alerta_rendimiento: string | null;
  foto_ticket_url: string | null;
  fecha_carga: Date;
  creado_offline: boolean;
  sincronizado_en: Date | null;
}

function serializar(c: Carga): CargaPublica {
  return {
    id: c.id,
    solicitud_id: c.solicitudId,
    chofer_id: c.choferId,
    vehiculo_id: c.vehiculoId,
    obra_id: c.obraId,
    litros: numeroDesdeDecimal(c.litros) ?? 0,
    precio_por_litro: numeroDesdeDecimal(c.precioPorLitro) ?? 0,
    monto_total: numeroDesdeDecimal(c.montoTotal) ?? 0,
    km_actual: enteroDesdeDecimal(c.kmActual),
    km_anterior: enteroDesdeDecimal(c.kmAnterior),
    rendimiento_km_l: numeroDesdeDecimal(c.rendimientoKmL),
    horas_actual: enteroDesdeDecimal(c.horasActual),
    horas_anterior: enteroDesdeDecimal(c.horasAnterior),
    rendimiento_l_h: numeroDesdeDecimal(c.rendimientoLH),
    alerta_rendimiento: c.alertaRendimiento,
    foto_ticket_url: c.fotoTicketUrl,
    fecha_carga: c.fechaCarga,
    creado_offline: c.creadoOffline,
    sincronizado_en: c.sincronizadoEn,
  };
}

/**
 * Umbrales de rendimiento km/L (design/README.md):
 * <3 o >15 => revisar, 3–6 => bajo, >6 (hasta 15) => normal.
 */
function calcularAlerta(rendimientoKmL: number): AlertaRendimientoTipo {
  if (rendimientoKmL < 3 || rendimientoKmL > 15) return "revisar";
  if (rendimientoKmL <= 6) return "bajo";
  return "normal";
}

export interface DatosCrearCarga {
  id?: unknown;
  solicitud_id: unknown;
  vehiculo_id: unknown;
  litros: unknown;
  precio_por_litro: unknown;
  km_actual?: unknown;
  km_anterior?: unknown;
  horas_actual?: unknown;
  horas_anterior?: unknown;
  fecha_carga?: unknown;
  creado_offline?: unknown;
}

export async function crear(user: AuthTokenPayload, datos: DatosCrearCarga): Promise<CargaPublica> {
  // id opcional: lo manda el cliente cuando la carga se registró offline
  // (PowerSync/uuid del lado de Flutter, ver frontend/lib/services/powersync/).
  // Usarlo tal cual evita que el registro optimista local y el real terminen
  // con ids distintos — si no se manda, se sigue generando uno nuevo (default
  // de Prisma/Postgres, ver schema.prisma).
  let id: string | undefined;
  if (datos.id !== undefined && datos.id !== null) {
    if (!esUuidValido(datos.id)) {
      throw new AppError(400, "id debe ser un UUID válido.");
    }
    const existente = await prisma.carga.findUnique({ where: { id: datos.id } });
    if (existente) {
      throw new AppError(409, "Ya existe una carga con ese id.");
    }
    id = datos.id;
  }

  if (!esStringNoVacia(datos.solicitud_id, 100)) {
    throw new AppError(400, "solicitud_id es requerido y debe ser un texto válido.");
  }
  if (!esStringNoVacia(datos.vehiculo_id, 100)) {
    throw new AppError(400, "vehiculo_id es requerido y debe ser un texto válido.");
  }
  if (!esNumeroPositivo(datos.litros)) {
    throw new AppError(400, "litros debe ser un número mayor a 0.");
  }
  if (!esNumeroPositivo(datos.precio_por_litro)) {
    throw new AppError(400, "precio_por_litro debe ser un número mayor a 0.");
  }
  if (datos.km_actual !== undefined && datos.km_actual !== null && !esNumeroNoNegativo(datos.km_actual)) {
    throw new AppError(400, "km_actual debe ser un número no negativo.");
  }
  if (
    datos.km_anterior !== undefined &&
    datos.km_anterior !== null &&
    !esNumeroNoNegativo(datos.km_anterior)
  ) {
    throw new AppError(400, "km_anterior debe ser un número no negativo.");
  }
  if (
    datos.horas_actual !== undefined &&
    datos.horas_actual !== null &&
    !esNumeroNoNegativo(datos.horas_actual)
  ) {
    throw new AppError(400, "horas_actual debe ser un número no negativo.");
  }
  if (
    datos.horas_anterior !== undefined &&
    datos.horas_anterior !== null &&
    !esNumeroNoNegativo(datos.horas_anterior)
  ) {
    throw new AppError(400, "horas_anterior debe ser un número no negativo.");
  }
  if (datos.fecha_carga !== undefined && datos.fecha_carga !== null && !esFechaISOValida(datos.fecha_carga)) {
    throw new AppError(400, "fecha_carga debe ser una fecha válida.");
  }
  if (datos.creado_offline !== undefined && typeof datos.creado_offline !== "boolean") {
    throw new AppError(400, "creado_offline debe ser booleano.");
  }

  const kmActual = (datos.km_actual as number | undefined) ?? null;
  const kmAnterior = (datos.km_anterior as number | undefined) ?? null;
  if (kmActual !== null && kmAnterior !== null && kmActual < kmAnterior) {
    throw new AppError(400, "km_actual debe ser mayor o igual a km_anterior.");
  }

  const horasActual = (datos.horas_actual as number | undefined) ?? null;
  const horasAnterior = (datos.horas_anterior as number | undefined) ?? null;
  if (horasActual !== null && horasAnterior !== null && horasActual < horasAnterior) {
    throw new AppError(400, "horas_actual debe ser mayor o igual a horas_anterior.");
  }

  const solicitud = await prisma.solicitudAutorizacion.findUnique({
    where: { id: datos.solicitud_id },
  });
  if (!solicitud) {
    throw new AppError(400, "solicitud_id no corresponde a una solicitud existente.");
  }
  // Un chofer nunca registra una carga contra la solicitud de otro chofer,
  // aunque mande un solicitud_id válido de alguien más.
  if (solicitud.choferId !== user.perfilId) {
    throw new AppError(403, "No puedes registrar una carga para la solicitud de otro chofer.");
  }
  if (solicitud.estado !== "autorizado") {
    throw new AppError(400, "La solicitud debe estar autorizada antes de registrar la carga.");
  }
  if (solicitud.vehiculoId !== datos.vehiculo_id) {
    throw new AppError(400, "vehiculo_id no coincide con el de la solicitud autorizada.");
  }

  const vehiculo = await prisma.vehiculo.findUnique({ where: { id: datos.vehiculo_id } });
  if (!vehiculo) {
    throw new AppError(400, "vehiculo_id no corresponde a un vehículo existente.");
  }
  // km_actual/km_anterior son para vehículos con kilometraje; horas_actual/horas_anterior
  // son el horómetro de maquinaria pesada (alternativa a km). Son mutuamente excluyentes.
  if (vehiculo.tipoUnidad === "maquinaria" && (kmActual !== null || kmAnterior !== null)) {
    throw new AppError(400, "km_actual/km_anterior no aplican para maquinaria pesada; usa horas_actual/horas_anterior.");
  }
  if (vehiculo.tipoUnidad === "vehiculo" && (horasActual !== null || horasAnterior !== null)) {
    throw new AppError(400, "horas_actual/horas_anterior no aplican para vehículos con kilometraje; usa km_actual/km_anterior.");
  }

  let rendimientoKmL: number | null = null;
  let rendimientoLH: number | null = null;
  let alertaRendimiento: AlertaRendimientoTipo | null = null;
  if (kmActual !== null && kmAnterior !== null) {
    const kmRecorridos = kmActual - kmAnterior;
    rendimientoKmL = Math.round((kmRecorridos / (datos.litros as number)) * 100) / 100;
    alertaRendimiento = calcularAlerta(rendimientoKmL);
  }
  if (horasActual !== null && horasAnterior !== null) {
    const horasTranscurridas = horasActual - horasAnterior;
    rendimientoLH =
      horasTranscurridas > 0
        ? Math.round(((datos.litros as number) / horasTranscurridas) * 100) / 100
        : null;
  }

  let carga: Carga;
  try {
    [carga] = await prisma.$transaction([
      prisma.carga.create({
        data: {
          // id: si vino del cliente ya se validó arriba que no exista; si es
          // undefined, Prisma usa el default (uuid_generate_v4(), ver schema.prisma).
          id,
          solicitudId: solicitud.id,
          // chofer_id y obra_id nunca se toman del body: siempre del token/solicitud.
          choferId: user.perfilId,
          vehiculoId: datos.vehiculo_id,
          obraId: solicitud.obraId,
          litros: datos.litros,
          precioPorLitro: datos.precio_por_litro,
          kmActual,
          kmAnterior,
          rendimientoKmL,
          horasActual,
          horasAnterior,
          rendimientoLH,
          alertaRendimiento,
          fechaCarga: datos.fecha_carga ? new Date(datos.fecha_carga as string) : new Date(),
          creadoOffline: (datos.creado_offline as boolean | undefined) ?? false,
        },
      }),
      prisma.solicitudAutorizacion.update({
        where: { id: solicitud.id },
        data: { estado: "cargado" },
      }),
    ]);
  } catch (error) {
    // Red de seguridad ante la carrera entre el findUnique de arriba y este
    // create (dos requests concurrentes con el mismo id offline): el check
    // previo cubre el caso común (secuencial), esto cubre el concurrente.
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      throw new AppError(409, "Ya existe una carga con ese id.");
    }
    throw error;
  }

  return serializar(carga);
}

export async function listarPorChofer(
  user: AuthTokenPayload,
  choferId: string
): Promise<CargaPublica[]> {
  const choferIdEfectivo = user.rol === "chofer" ? user.perfilId : choferId;

  if (user.rol === "administrativo" && !user.obraId) {
    throw new AppError(403, "Tu usuario no tiene una obra asignada.");
  }

  const cargas = await prisma.carga.findMany({
    where: {
      choferId: choferIdEfectivo,
      ...(user.rol === "administrativo" ? { obraId: user.obraId as string } : {}),
    },
    orderBy: { fechaCarga: "desc" },
  });
  return cargas.map(serializar);
}

export async function listarPorObra(user: AuthTokenPayload, obraId: string): Promise<CargaPublica[]> {
  asegurarAccesoObra(user, obraId);
  const cargas = await prisma.carga.findMany({
    where: { obraId },
    orderBy: { fechaCarga: "desc" },
  });
  return cargas.map(serializar);
}

export async function subirFotoTicket(
  user: AuthTokenPayload,
  cargaId: string,
  urlPublica: string
): Promise<CargaPublica> {
  const carga = await prisma.carga.findUnique({ where: { id: cargaId } });
  if (!carga) {
    throw new AppError(404, "Carga no encontrada.");
  }
  if (carga.choferId !== user.perfilId) {
    throw new AppError(403, "No puedes modificar la carga de otro chofer.");
  }

  const actualizada = await prisma.carga.update({
    where: { id: cargaId },
    data: { fotoTicketUrl: urlPublica },
  });
  return serializar(actualizada);
}
