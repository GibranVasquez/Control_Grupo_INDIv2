import { Prisma, SolicitudAutorizacion } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { asegurarAccesoObra } from "../utils/accesoObra";
import { numeroDesdeDecimal } from "../utils/decimal";
import {
  esNumeroNoNegativo,
  esNumeroPositivo,
  esStringNoVacia,
  esUuidValido,
} from "../utils/validacion";
import { AuthTokenPayload } from "../types/auth";

const ESTADOS_RESOLUCION = ["autorizado", "rechazado"] as const;

export interface SolicitudAutorizacionPublica {
  id: string;
  chofer_id: string;
  vehiculo_id: string;
  obra_id: string;
  litros_solicitados: number;
  litros_autorizados: number | null;
  comentario: string | null;
  estado: string;
  resuelto_por: string | null;
  resuelto_en: Date | null;
  creado_en: Date;
  creado_offline: boolean;
  actividad: string | null;
  responsable: string | null;
}

function serializar(s: SolicitudAutorizacion): SolicitudAutorizacionPublica {
  return {
    id: s.id,
    chofer_id: s.choferId,
    vehiculo_id: s.vehiculoId,
    obra_id: s.obraId,
    litros_solicitados: numeroDesdeDecimal(s.litrosSolicitados) ?? 0,
    litros_autorizados: numeroDesdeDecimal(s.litrosAutorizados),
    comentario: s.comentario,
    estado: s.estado,
    resuelto_por: s.resueltoPorId,
    resuelto_en: s.resueltoEn,
    creado_en: s.creadoEn,
    creado_offline: s.creadoOffline,
    actividad: s.actividad,
    responsable: s.responsable,
  };
}

export interface DatosCrearSolicitud {
  id?: unknown;
  vehiculo_id: unknown;
  litros_solicitados: unknown;
  comentario?: unknown;
  actividad?: unknown;
  responsable?: unknown;
  creado_offline?: unknown;
}

export async function crear(
  user: AuthTokenPayload,
  datos: DatosCrearSolicitud
): Promise<SolicitudAutorizacionPublica> {
  // id opcional: lo manda el cliente cuando la solicitud se creó offline
  // (PowerSync/uuid del lado de Flutter, ver frontend/lib/services/powersync/).
  // Usarlo tal cual evita que el registro optimista local y el real terminen
  // con ids distintos — si no se manda, se sigue generando uno nuevo (default
  // de Prisma/Postgres, ver schema.prisma).
  let id: string | undefined;
  if (datos.id !== undefined && datos.id !== null) {
    if (!esUuidValido(datos.id)) {
      throw new AppError(400, "id debe ser un UUID válido.");
    }
    const existente = await prisma.solicitudAutorizacion.findUnique({ where: { id: datos.id } });
    if (existente) {
      throw new AppError(409, "Ya existe una solicitud de autorización con ese id.");
    }
    id = datos.id;
  }

  if (!esStringNoVacia(datos.vehiculo_id, 100)) {
    throw new AppError(400, "vehiculo_id es requerido y debe ser un texto válido.");
  }
  if (!esNumeroPositivo(datos.litros_solicitados)) {
    throw new AppError(400, "litros_solicitados debe ser un número mayor a 0.");
  }
  if (datos.comentario !== undefined && datos.comentario !== null && typeof datos.comentario !== "string") {
    throw new AppError(400, "comentario debe ser un texto.");
  }
  if (datos.actividad !== undefined && datos.actividad !== null && typeof datos.actividad !== "string") {
    throw new AppError(400, "actividad debe ser un texto.");
  }
  if (
    datos.responsable !== undefined &&
    datos.responsable !== null &&
    typeof datos.responsable !== "string"
  ) {
    throw new AppError(400, "responsable debe ser un texto.");
  }
  if (datos.creado_offline !== undefined && typeof datos.creado_offline !== "boolean") {
    throw new AppError(400, "creado_offline debe ser booleano.");
  }

  if (!user.obraId) {
    throw new AppError(403, "Tu usuario no tiene una obra asignada.");
  }

  const vehiculo = await prisma.vehiculo.findUnique({ where: { id: datos.vehiculo_id } });
  if (!vehiculo) {
    throw new AppError(400, "vehiculo_id no corresponde a un vehículo existente.");
  }
  // El chofer solo puede pedir combustible para un vehículo de su propia obra.
  asegurarAccesoObra(user, vehiculo.obraId);

  let solicitud: SolicitudAutorizacion;
  try {
    solicitud = await prisma.solicitudAutorizacion.create({
      data: {
        // id: si vino del cliente ya se validó arriba que no exista; si es
        // undefined, Prisma usa el default (uuid_generate_v4(), ver schema.prisma).
        id,
        // chofer_id y obra_id nunca se toman del body: siempre del token,
        // aunque el cliente mande otro valor.
        choferId: user.perfilId,
        obraId: user.obraId,
        vehiculoId: datos.vehiculo_id,
        litrosSolicitados: datos.litros_solicitados,
        comentario: (datos.comentario as string | undefined) ?? null,
        actividad: (datos.actividad as string | undefined) ?? null,
        responsable: (datos.responsable as string | undefined) ?? null,
        creadoOffline: (datos.creado_offline as boolean | undefined) ?? false,
        estado: "pendiente",
      },
    });
  } catch (error) {
    // Red de seguridad ante la carrera entre el findUnique de arriba y este
    // create (dos requests concurrentes con el mismo id offline): el check
    // previo cubre el caso común (secuencial), esto cubre el concurrente.
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      throw new AppError(409, "Ya existe una solicitud de autorización con ese id.");
    }
    throw error;
  }
  return serializar(solicitud);
}

export async function listarPorChofer(
  user: AuthTokenPayload,
  choferId: string
): Promise<SolicitudAutorizacionPublica[]> {
  // El chofer solo puede ver las suyas, sin importar qué chofer_id pida.
  const choferIdEfectivo = user.rol === "chofer" ? user.perfilId : choferId;

  if (user.rol === "administrativo" && !user.obraId) {
    throw new AppError(403, "Tu usuario no tiene una obra asignada.");
  }

  const solicitudes = await prisma.solicitudAutorizacion.findMany({
    where: {
      choferId: choferIdEfectivo,
      // administrativo solo ve choferes de su propia obra; si el chofer
      // pedido no es de su obra, esto simplemente no regresa nada.
      ...(user.rol === "administrativo" ? { obraId: user.obraId as string } : {}),
    },
    orderBy: { creadoEn: "desc" },
  });
  return solicitudes.map(serializar);
}

export async function listarPendientesPorObra(
  user: AuthTokenPayload,
  obraId: string
): Promise<SolicitudAutorizacionPublica[]> {
  asegurarAccesoObra(user, obraId);
  const solicitudes = await prisma.solicitudAutorizacion.findMany({
    where: { obraId, estado: "pendiente" },
    orderBy: { creadoEn: "asc" },
  });
  return solicitudes.map(serializar);
}

export interface DatosResolverSolicitud {
  estado: unknown;
  litros_autorizados?: unknown;
  comentario?: unknown;
}

export async function resolver(
  user: AuthTokenPayload,
  solicitudId: string,
  datos: DatosResolverSolicitud
): Promise<SolicitudAutorizacionPublica> {
  if (
    typeof datos.estado !== "string" ||
    !ESTADOS_RESOLUCION.includes(datos.estado as (typeof ESTADOS_RESOLUCION)[number])
  ) {
    throw new AppError(400, `estado debe ser uno de: ${ESTADOS_RESOLUCION.join(", ")}.`);
  }
  if (
    datos.litros_autorizados !== undefined &&
    datos.litros_autorizados !== null &&
    !esNumeroNoNegativo(datos.litros_autorizados)
  ) {
    throw new AppError(400, "litros_autorizados debe ser un número no negativo.");
  }
  if (datos.comentario !== undefined && datos.comentario !== null && typeof datos.comentario !== "string") {
    throw new AppError(400, "comentario debe ser un texto.");
  }

  const solicitud = await prisma.solicitudAutorizacion.findUnique({ where: { id: solicitudId } });
  if (!solicitud) {
    throw new AppError(404, "Solicitud no encontrada.");
  }
  asegurarAccesoObra(user, solicitud.obraId);

  if (solicitud.estado !== "pendiente") {
    throw new AppError(400, "Esta solicitud ya fue resuelta.");
  }

  const comentario = (datos.comentario as string | undefined)?.trim();
  const estado = datos.estado as (typeof ESTADOS_RESOLUCION)[number];

  let litrosAutorizados: number | null = null;

  if (estado === "rechazado") {
    if (!comentario) {
      throw new AppError(400, "comentario es obligatorio al rechazar una solicitud.");
    }
  } else {
    const litrosSolicitados = numeroDesdeDecimal(solicitud.litrosSolicitados) ?? 0;
    litrosAutorizados =
      datos.litros_autorizados === undefined || datos.litros_autorizados === null
        ? litrosSolicitados
        : (datos.litros_autorizados as number);

    if (litrosAutorizados < litrosSolicitados && !comentario) {
      throw new AppError(
        400,
        "comentario es obligatorio cuando litros_autorizados es menor a litros_solicitados."
      );
    }
  }

  const actualizada = await prisma.solicitudAutorizacion.update({
    where: { id: solicitudId },
    data: {
      estado,
      litrosAutorizados: estado === "autorizado" ? litrosAutorizados : null,
      comentario: comentario ?? solicitud.comentario,
      resueltoPorId: user.perfilId,
      resueltoEn: new Date(),
    },
  });
  return serializar(actualizada);
}

/** Uso interno de carga.service: obtiene la solicitud cruda, sin serializar. */
export async function obtenerCruda(solicitudId: string) {
  return prisma.solicitudAutorizacion.findUnique({ where: { id: solicitudId } });
}
