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
  vigente_hasta: Date | null;
}

function serializar(p: PrecioCombustible): PrecioCombustiblePublico {
  return {
    id: p.id,
    tipo_combustible: p.tipoCombustible,
    precio_por_litro: numeroDesdeDecimal(p.precioPorLitro) ?? 0,
    vigente_desde: p.vigenteDesde,
    vigente_hasta: p.vigenteHasta,
  };
}

/** Un día antes de `fecha` (mismo campo @db.Date: sin componente de hora). */
function diaAnterior(fecha: Date): Date {
  const anterior = new Date(fecha);
  anterior.setUTCDate(anterior.getUTCDate() - 1);
  return anterior;
}

/**
 * Otro precio del mismo tipo que solaparía con el rango [vigenteDesde, ∞)
 * de un precio nuevo o editado (siempre de final abierto hasta que se cierra
 * automáticamente al dar de alta el siguiente). `excluirId` se usa en PUT
 * para no comparar el registro contra sí mismo.
 */
async function buscarSolapado(
  tipoCombustible: TipoCombustible,
  vigenteDesde: Date,
  excluirId?: string,
  vigenteHastaPropia?: Date | null
): Promise<PrecioCombustible | null> {
  return prisma.precioCombustible.findFirst({
    where: {
      tipoCombustible,
      ...(excluirId ? { id: { not: excluirId } } : {}),
      OR: [{ vigenteHasta: null }, { vigenteHasta: { gte: vigenteDesde } }],
      // Si el rango propio también tiene un final (PUT sobre un precio ya
      // cerrado), el solapamiento también exige que el otro precio empiece
      // antes de ese final; si el rango propio es abierto (crear, o editar
      // el precio vigente actual), esta condición no aplica.
      ...(vigenteHastaPropia ? { vigenteDesde: { lte: vigenteHastaPropia } } : {}),
    },
  });
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

/** Lista todos los precios (de cualquier tipo). Con `soloVigentes`, uno por
 * tipo_combustible: el que está actualmente abierto (vigente_hasta null y
 * vigente_desde ya alcanzado). */
export async function listar(soloVigentes: boolean): Promise<PrecioCombustiblePublico[]> {
  if (!soloVigentes) {
    const precios = await prisma.precioCombustible.findMany({
      orderBy: [{ tipoCombustible: "asc" }, { vigenteDesde: "desc" }],
    });
    return precios.map(serializar);
  }

  const vigentes = await Promise.all(
    TIPOS_COMBUSTIBLE.map((tipo) => buscarVigente(tipo))
  );
  return vigentes.filter((p): p is PrecioCombustible => p !== null).map(serializar);
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
  const vigenteDesde = new Date(datos.vigente_desde as string);

  // El precio actualmente abierto (sin vigente_hasta) de este tipo, si hay
  // uno: se cierra automáticamente para que nunca queden dos precios
  // vigentes del mismo combustible a la vez.
  const abierto = await prisma.precioCombustible.findFirst({
    where: { tipoCombustible, vigenteHasta: null },
  });
  if (abierto && vigenteDesde <= abierto.vigenteDesde) {
    throw new AppError(
      400,
      `vigente_desde debe ser posterior al del precio vigente actual (${abierto.vigenteDesde.toISOString().slice(0, 10)}).`
    );
  }

  // Solapamiento contra cualquier otro precio del mismo tipo (histórico
  // incluido); el que está abierto ya se validó arriba y se excluye aquí
  // porque esta misma operación lo va a cerrar.
  const solapado = await buscarSolapado(tipoCombustible, vigenteDesde, abierto?.id);
  if (solapado) {
    throw new AppError(
      400,
      `vigente_desde se solapa con otro precio ya registrado (id ${solapado.id}).`
    );
  }

  // Copia a variable local tipada: dentro del closure de $transaction abajo
  // TypeScript no conserva el angostamiento de esNumeroPositivo sobre
  // datos.precio_por_litro (no es una variable local), ver mismo patrón en
  // carga.service.ts.
  const precioPorLitro = datos.precio_por_litro as number;

  const precio = await prisma.$transaction(async (tx) => {
    if (abierto) {
      await tx.precioCombustible.update({
        where: { id: abierto.id },
        data: { vigenteHasta: diaAnterior(vigenteDesde) },
      });
    }
    return tx.precioCombustible.create({
      data: {
        tipoCombustible,
        precioPorLitro,
        vigenteDesde,
        creadoPorId: user.perfilId,
      },
    });
  });
  return serializar(precio);
}

/** Aproximación de "cargas que usaron este precio": no existe una FK
 * precio_id en `cargas` (solo se guarda el precio_por_litro copiado al
 * momento de la carga, ver carga.service.ts), así que se identifica por
 * coincidencia de tipo_combustible (vía vehículo) + fecha_carga dentro de
 * la vigencia + precio_por_litro exacto. */
async function existeCargaConEstePrecio(precio: PrecioCombustible): Promise<boolean> {
  const carga = await prisma.carga.findFirst({
    where: {
      precioPorLitro: precio.precioPorLitro,
      fechaCarga: {
        gte: precio.vigenteDesde,
        ...(precio.vigenteHasta ? { lte: precio.vigenteHasta } : {}),
      },
      vehiculo: { tipoCombustible: precio.tipoCombustible },
    },
  });
  return carga !== null;
}

export interface DatosActualizarPrecio {
  tipo_combustible?: unknown;
  precio_por_litro?: unknown;
  vigente_desde?: unknown;
}

export async function actualizar(
  id: string,
  datos: DatosActualizarPrecio
): Promise<PrecioCombustiblePublico> {
  const precio = await prisma.precioCombustible.findUnique({ where: { id } });
  if (!precio) {
    throw new AppError(404, "Precio no encontrado.");
  }

  if (await existeCargaConEstePrecio(precio)) {
    throw new AppError(
      409,
      "No se puede editar: ya existen cargas registradas con este precio (no se altera el histórico financiero)."
    );
  }

  const tipoCombustible =
    datos.tipo_combustible !== undefined ? validarTipo(datos.tipo_combustible) : precio.tipoCombustible;

  if (datos.precio_por_litro !== undefined && !esNumeroPositivo(datos.precio_por_litro)) {
    throw new AppError(400, "precio_por_litro debe ser un número mayor a 0.");
  }
  const precioPorLitro = datos.precio_por_litro !== undefined ? datos.precio_por_litro : precio.precioPorLitro;

  let vigenteDesde = precio.vigenteDesde;
  if (datos.vigente_desde !== undefined) {
    if (!esFechaISOValida(datos.vigente_desde)) {
      throw new AppError(400, "vigente_desde debe ser una fecha válida.");
    }
    vigenteDesde = new Date(datos.vigente_desde as string);
  }

  if (precio.vigenteHasta && vigenteDesde >= precio.vigenteHasta) {
    throw new AppError(400, "vigente_desde debe ser anterior a vigente_hasta.");
  }

  const solapado = await buscarSolapado(tipoCombustible, vigenteDesde, precio.id, precio.vigenteHasta);
  if (solapado) {
    throw new AppError(
      400,
      `vigente_desde se solapa con otro precio ya registrado (id ${solapado.id}).`
    );
  }

  const actualizado = await prisma.precioCombustible.update({
    where: { id },
    data: { tipoCombustible, precioPorLitro, vigenteDesde },
  });
  return serializar(actualizado);
}
