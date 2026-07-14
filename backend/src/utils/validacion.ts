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

const REGEX_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Acepta cualquier UUID RFC 4122 (v1-v5); es lo que genera el paquete `uuid`
 * usado del lado del cliente (PowerSync/Flutter) al insertar offline. */
export function esUuidValido(valor: unknown): valor is string {
  return typeof valor === "string" && REGEX_UUID.test(valor);
}

const REGEX_CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function esCorreoValido(valor: unknown): valor is string {
  return esStringNoVacia(valor, 200) && REGEX_CORREO.test(valor.trim());
}

/** Normaliza a minúsculas antes de guardar/comparar: el unique constraint de
 * `correo` en Postgres es case-sensitive, así que sin esto "Juan@x.com" y
 * "juan@x.com" no chocarían entre sí pese a ser el mismo correo. */
export function normalizarCorreo(correo: string): string {
  return correo.trim().toLowerCase();
}

export function valorDeQuery(valor: unknown): string | undefined {
  return typeof valor === "string" && valor.length > 0 ? valor : undefined;
}

/** req.params tipa cada valor como `string | string[]` (por rutas comodín); en
 * rutas con `:id` simple siempre es un string. */
export function paramString(valor: string | string[]): string {
  return Array.isArray(valor) ? valor[0] : valor;
}
