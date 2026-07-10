export function esStringNoVacia(valor: unknown, longitudMaxima = 500): valor is string {
  return typeof valor === "string" && valor.trim().length > 0 && valor.length <= longitudMaxima;
}

export function esNumeroNoNegativo(valor: unknown): valor is number {
  return typeof valor === "number" && Number.isFinite(valor) && valor >= 0;
}

export function esNumeroPositivo(valor: unknown): valor is number {
  return typeof valor === "number" && Number.isFinite(valor) && valor > 0;
}

export function esEnteroNoNegativo(valor: unknown): valor is number {
  return typeof valor === "number" && Number.isInteger(valor) && valor >= 0;
}

export function esFechaISOValida(valor: unknown): valor is string {
  return typeof valor === "string" && !Number.isNaN(Date.parse(valor));
}

export function valorDeQuery(valor: unknown): string | undefined {
  return typeof valor === "string" && valor.length > 0 ? valor : undefined;
}

/** req.params tipa cada valor como `string | string[]` (por rutas comodín); en
 * rutas con `:id` simple siempre es un string. */
export function paramString(valor: string | string[]): string {
  return Array.isArray(valor) ? valor[0] : valor;
}
