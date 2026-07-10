import { Vehiculo } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { asegurarAccesoObra } from "../utils/accesoObra";
import { numeroDesdeDecimal } from "../utils/decimal";
import { esEnteroNoNegativo, esNumeroNoNegativo, esStringNoVacia } from "../utils/validacion";
import { AuthTokenPayload } from "../types/auth";

const TIPOS_COMBUSTIBLE = ["magna", "premium", "diesel"] as const;
const ESTADOS_VEHICULO = ["activo", "taller", "baja"] as const;
const TIPOS_UNIDAD = ["vehiculo", "maquinaria"] as const;

export interface VehiculoPublico {
  id: string;
  placa: string;
  marca: string;
  modelo: string;
  anio: number | null;
  tipo_combustible: string;
  tope_litros_semanal: number;
  obra_id: string;
  estado: string;
  tipo_unidad: string;
}

function serializar(vehiculo: Vehiculo): VehiculoPublico {
  return {
    id: vehiculo.id,
    placa: vehiculo.placa,
    marca: vehiculo.marca,
    modelo: vehiculo.modelo,
    anio: vehiculo.anio,
    tipo_combustible: vehiculo.tipoCombustible,
    tope_litros_semanal: numeroDesdeDecimal(vehiculo.topeLitrosSemanal) ?? 0,
    obra_id: vehiculo.obraId,
    estado: vehiculo.estado,
    tipo_unidad: vehiculo.tipoUnidad,
  };
}

export interface DatosVehiculo {
  placa: unknown;
  marca: unknown;
  modelo: unknown;
  anio?: unknown;
  tipo_combustible: unknown;
  tope_litros_semanal: unknown;
  estado?: unknown;
  tipo_unidad?: unknown;
}

function validarDatosVehiculo(datos: DatosVehiculo): {
  placa: string;
  marca: string;
  modelo: string;
  anio: number | null;
  tipoCombustible: (typeof TIPOS_COMBUSTIBLE)[number];
  topeLitrosSemanal: number;
  estado: (typeof ESTADOS_VEHICULO)[number];
  tipoUnidad: (typeof TIPOS_UNIDAD)[number];
} {
  if (!esStringNoVacia(datos.placa, 50)) {
    throw new AppError(400, "placa es requerida y debe ser un texto válido.");
  }
  if (!esStringNoVacia(datos.marca, 100)) {
    throw new AppError(400, "marca es requerida y debe ser un texto válido.");
  }
  if (!esStringNoVacia(datos.modelo, 100)) {
    throw new AppError(400, "modelo es requerido y debe ser un texto válido.");
  }
  if (datos.anio !== undefined && datos.anio !== null && !esEnteroNoNegativo(datos.anio)) {
    throw new AppError(400, "anio debe ser un entero no negativo.");
  }
  if (
    typeof datos.tipo_combustible !== "string" ||
    !TIPOS_COMBUSTIBLE.includes(datos.tipo_combustible as (typeof TIPOS_COMBUSTIBLE)[number])
  ) {
    throw new AppError(400, `tipo_combustible debe ser uno de: ${TIPOS_COMBUSTIBLE.join(", ")}.`);
  }
  if (!esNumeroNoNegativo(datos.tope_litros_semanal)) {
    throw new AppError(400, "tope_litros_semanal debe ser un número no negativo.");
  }
  const estado = datos.estado ?? "activo";
  if (typeof estado !== "string" || !ESTADOS_VEHICULO.includes(estado as (typeof ESTADOS_VEHICULO)[number])) {
    throw new AppError(400, `estado debe ser uno de: ${ESTADOS_VEHICULO.join(", ")}.`);
  }
  const tipoUnidad = datos.tipo_unidad ?? "vehiculo";
  if (typeof tipoUnidad !== "string" || !TIPOS_UNIDAD.includes(tipoUnidad as (typeof TIPOS_UNIDAD)[number])) {
    throw new AppError(400, `tipo_unidad debe ser uno de: ${TIPOS_UNIDAD.join(", ")}.`);
  }

  return {
    placa: datos.placa,
    marca: datos.marca,
    modelo: datos.modelo,
    anio: datos.anio === undefined || datos.anio === null ? null : (datos.anio as number),
    tipoCombustible: datos.tipo_combustible as (typeof TIPOS_COMBUSTIBLE)[number],
    topeLitrosSemanal: datos.tope_litros_semanal as number,
    estado: estado as (typeof ESTADOS_VEHICULO)[number],
    tipoUnidad: tipoUnidad as (typeof TIPOS_UNIDAD)[number],
  };
}

export async function listarPorObra(
  user: AuthTokenPayload,
  obraId: string
): Promise<VehiculoPublico[]> {
  asegurarAccesoObra(user, obraId);
  const vehiculos = await prisma.vehiculo.findMany({
    where: { obraId },
    orderBy: { placa: "asc" },
  });
  return vehiculos.map(serializar);
}

export async function obtenerPorId(
  user: AuthTokenPayload,
  vehiculoId: string
): Promise<VehiculoPublico> {
  const vehiculo = await prisma.vehiculo.findUnique({ where: { id: vehiculoId } });
  if (!vehiculo) {
    throw new AppError(404, "Vehículo no encontrado.");
  }
  asegurarAccesoObra(user, vehiculo.obraId);
  return serializar(vehiculo);
}

export async function crear(
  user: AuthTokenPayload,
  datos: DatosVehiculo
): Promise<VehiculoPublico> {
  const validado = validarDatosVehiculo(datos);
  // administrativo solo puede crear vehículos para su propia obra: se ignora
  // cualquier obra_id que mande el cliente y se usa la del token.
  if (!user.obraId) {
    throw new AppError(403, "Tu usuario no tiene una obra asignada.");
  }
  const vehiculo = await prisma.vehiculo.create({
    data: { ...validado, obraId: user.obraId },
  });
  return serializar(vehiculo);
}

export async function actualizar(
  user: AuthTokenPayload,
  vehiculoId: string,
  datos: DatosVehiculo
): Promise<VehiculoPublico> {
  const existente = await prisma.vehiculo.findUnique({ where: { id: vehiculoId } });
  if (!existente) {
    throw new AppError(404, "Vehículo no encontrado.");
  }
  asegurarAccesoObra(user, existente.obraId);

  const validado = validarDatosVehiculo(datos);
  // La obra del vehículo no se cambia por esta vía (eso es competencia del
  // historial de reasignación), pase lo que pase en el body.
  const vehiculo = await prisma.vehiculo.update({
    where: { id: vehiculoId },
    data: validado,
  });
  return serializar(vehiculo);
}
