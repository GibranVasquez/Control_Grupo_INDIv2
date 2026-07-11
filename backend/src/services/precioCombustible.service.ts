import { PrecioCombustible } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { numeroDesdeDecimal } from "../utils/decimal";
import { esFechaISOValida, esNumeroPositivo } from "../utils/validacion";
import { AuthTokenPayload } from "../types/auth";

const TIPOS_COMBUSTIBLE = ["magna", "premium", "diesel"] as const;
type TipoCombustible = (typeof TIPOS_COMBUSTIBLE)[number];

export interface PrecioCombustiblePublico {
  id: string;
  tipo_combustible: string;
  precio_por_litro: number;
  vigente_desde: Date;
}

function serializar(p: PrecioCombustible): PrecioCombustiblePublico {
  return {
    id: p.id,
    tipo_combustible: p.tipoCombustible,
    precio_por_litro: numeroDesdeDecimal(p.precioPorLitro) ?? 0,
    vigente_desde: p.vigenteDesde,
  };
}

function validarTipo(tipo: unknown): TipoCombustible {
  if (typeof tipo !== "string" || !TIPOS_COMBUSTIBLE.includes(tipo as TipoCombustible)) {
    throw new AppError(400, `tipo debe ser uno de: ${TIPOS_COMBUSTIBLE.join(", ")}.`);
  }
  return tipo as TipoCombustible;
}

/** Uso interno de otros servicios (p.ej. carga.service): el precio vigente
 * crudo (sin serializar) para un tipo de combustible, o null si no hay uno. */
export async function buscarVigente(
  tipoCombustible: TipoCombustible
): Promise<PrecioCombustible | null> {
  return prisma.precioCombustible.findFirst({
    where: { tipoCombustible, vigenteDesde: { lte: new Date() } },
    orderBy: { vigenteDesde: "desc" },
  });
}

export async function obtenerVigente(tipo: unknown): Promise<PrecioCombustiblePublico> {
  const tipoValidado = validarTipo(tipo);
  const precio = await buscarVigente(tipoValidado);
  if (!precio) {
    throw new AppError(404, "No hay un precio vigente para este tipo de combustible.");
  }
  return serializar(precio);
}

export async function listarHistorico(tipo: unknown): Promise<PrecioCombustiblePublico[]> {
  const tipoValidado = validarTipo(tipo);
  const precios = await prisma.precioCombustible.findMany({
    where: { tipoCombustible: tipoValidado },
    orderBy: { vigenteDesde: "desc" },
  });
  return precios.map(serializar);
}

export interface DatosCrearPrecio {
  tipo_combustible: unknown;
  precio_por_litro: unknown;
  vigente_desde: unknown;
}

export async function crear(
  user: AuthTokenPayload,
  datos: DatosCrearPrecio
): Promise<PrecioCombustiblePublico> {
  const tipoCombustible = validarTipo(datos.tipo_combustible);
  if (!esNumeroPositivo(datos.precio_por_litro)) {
    throw new AppError(400, "precio_por_litro debe ser un número mayor a 0.");
  }
  if (!esFechaISOValida(datos.vigente_desde)) {
    throw new AppError(400, "vigente_desde debe ser una fecha válida.");
  }

  const precio = await prisma.precioCombustible.create({
    data: {
      tipoCombustible,
      precioPorLitro: datos.precio_por_litro,
      vigenteDesde: new Date(datos.vigente_desde as string),
      creadoPorId: user.perfilId,
    },
  });
  return serializar(precio);
}
