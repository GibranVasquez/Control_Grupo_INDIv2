import { NextFunction, Request, Response } from "express";

const LONGITUD_MAXIMA_NUMERO_EMPLEADO = 100;
const LONGITUD_MAXIMA_PASSWORD = 200;

function esStringNoVacia(valor: unknown, longitudMaxima: number): valor is string {
  return typeof valor === "string" && valor.trim().length > 0 && valor.length <= longitudMaxima;
}

export function validarLogin(req: Request, res: Response, next: NextFunction): void {
  const body = req.body ?? {};
  const { numero_empleado, password } = body;

  if (!esStringNoVacia(numero_empleado, LONGITUD_MAXIMA_NUMERO_EMPLEADO)) {
    res.status(400).json({ error: "numero_empleado es requerido y debe ser un texto válido." });
    return;
  }

  if (!esStringNoVacia(password, LONGITUD_MAXIMA_PASSWORD)) {
    res.status(400).json({ error: "password es requerido y debe ser un texto válido." });
    return;
  }

  next();
}
