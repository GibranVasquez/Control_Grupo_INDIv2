import { NextFunction, Request, Response } from "express";
import { MulterError } from "multer";
import { AppError } from "../utils/AppError";

const MENSAJE_ERROR_GENERICO = "Error interno del servidor";

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  console.error(err);

  if (err instanceof MulterError) {
    res.status(400).json({ error: `Archivo inválido: ${err.message}` });
    return;
  }

  if (err instanceof AppError) {
    res.status(err.status).json({ error: err.message });
    return;
  }

  const esProduccion = process.env.NODE_ENV === "production";
  const message =
    !esProduccion && err instanceof Error ? err.message : MENSAJE_ERROR_GENERICO;

  res.status(500).json({ error: message });
}
