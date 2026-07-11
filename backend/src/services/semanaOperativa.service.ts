import { SemanaOperativa } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { asegurarAccesoObra } from "../utils/accesoObra";
import { AuthTokenPayload } from "../types/auth";

export interface SemanaOperativaPublica {
  id: string;
  periodo_inicio: Date;
  periodo_fin: Date;
  estado: string;
}

function serializar(s: SemanaOperativa): SemanaOperativaPublica {
  return {
    id: s.id,
    periodo_inicio: s.periodoInicio,
    periodo_fin: s.periodoFin,
    estado: s.estado,
  };
}

export async function obtenerActual(
  user: AuthTokenPayload,
  obraIdQuery: string | undefined
): Promise<SemanaOperativaPublica> {
  let obraId: string;
  if (user.rol === "finanzas") {
    if (!obraIdQuery) {
      throw new AppError(400, "El parámetro obra_id es requerido.");
    }
    obraId = obraIdQuery;
  } else {
    if (!user.obraId) {
      throw new AppError(403, "Tu usuario no tiene una obra asignada.");
    }
    obraId = user.obraId;
  }

  const semana = await prisma.semanaOperativa.findFirst({
    where: { obraId, estado: "abierta" },
    orderBy: { periodoInicio: "desc" },
  });
  if (!semana) {
    throw new AppError(404, "No hay una semana operativa abierta para esta obra.");
  }
  return serializar(semana);
}

export async function cerrar(
  user: AuthTokenPayload,
  semanaId: string
): Promise<SemanaOperativaPublica> {
  const semana = await prisma.semanaOperativa.findUnique({ where: { id: semanaId } });
  if (!semana) {
    throw new AppError(404, "Semana operativa no encontrada.");
  }
  asegurarAccesoObra(user, semana.obraId);

  // Camino rápido: no basta por sí solo contra la carrera (dos cierres
  // concurrentes pueden pasar ambos por aquí antes de que cualquiera
  // escriba) — esa garantía la da el updateMany condicionado más abajo,
  // atómico a nivel de fila en Postgres (mismo patrón que
  // solicitudAutorizacion.service.ts).
  if (semana.estado === "cerrada") {
    throw new AppError(400, "Esta semana operativa ya está cerrada.");
  }

  const resultado = await prisma.semanaOperativa.updateMany({
    where: { id: semanaId, estado: "abierta" },
    data: { estado: "cerrada", cerradaPorId: user.perfilId, cerradaEn: new Date() },
  });
  if (resultado.count === 0) {
    throw new AppError(400, "Esta semana operativa ya está cerrada.");
  }

  const actualizada = await prisma.semanaOperativa.findUniqueOrThrow({ where: { id: semanaId } });
  return serializar(actualizada);
}
