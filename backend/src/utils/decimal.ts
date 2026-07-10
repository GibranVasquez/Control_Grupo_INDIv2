import { Prisma } from "@prisma/client";

/**
 * Prisma serializa Decimal a JSON como string (para no perder precisión).
 * El frontend espera números (`as num`), así que toda salida pasa por aquí.
 */
export function numeroDesdeDecimal(valor: Prisma.Decimal | null | undefined): number | null {
  if (valor === null || valor === undefined) return null;
  return valor.toNumber();
}

export function enteroDesdeDecimal(valor: Prisma.Decimal | null | undefined): number | null {
  const numero = numeroDesdeDecimal(valor);
  return numero === null ? null : Math.round(numero);
}
