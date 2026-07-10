import { Obra } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { asegurarAccesoObra } from "../utils/accesoObra";
import { AuthTokenPayload } from "../types/auth";

export interface ObraPublica {
  id: string;
  nombre: string;
  ubicacion: string | null;
  estado: string;
  fecha_inicio: Date;
  fecha_fin: Date | null;
}

function serializar(obra: Obra): ObraPublica {
  return {
    id: obra.id,
    nombre: obra.nombre,
    ubicacion: obra.ubicacion,
    estado: obra.estado,
    fecha_inicio: obra.fechaInicio,
    fecha_fin: obra.fechaFin,
  };
}

export async function obtenerPorId(user: AuthTokenPayload, obraId: string): Promise<ObraPublica> {
  const obra = await prisma.obra.findUnique({ where: { id: obraId } });
  if (!obra) {
    throw new AppError(404, "Obra no encontrada.");
  }
  asegurarAccesoObra(user, obra.id);
  return serializar(obra);
}

export async function listarTodas(): Promise<ObraPublica[]> {
  const obras = await prisma.obra.findMany({ orderBy: { nombre: "asc" } });
  return obras.map(serializar);
}
