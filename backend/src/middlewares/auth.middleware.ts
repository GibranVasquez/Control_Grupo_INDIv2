import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { esAuthTokenPayload } from "../types/auth";

const MENSAJE_NO_AUTORIZADO = "No autorizado.";

function rechazar(res: Response, motivoInterno: string): void {
  // El motivo detallado solo se registra en el log del servidor; el cliente
  // siempre recibe el mismo mensaje genérico, sin pistas sobre la causa.
  console.warn(`[auth] acceso rechazado: ${motivoInterno}`);
  res.status(401).json({ error: MENSAJE_NO_AUTORIZADO });
}

export function authMiddleware(req: Request, res: Response, next: NextFunction): void {
  const header = req.header("authorization");

  if (!header) {
    rechazar(res, "falta el header Authorization");
    return;
  }

  const [esquema, token] = header.split(" ");
  if (esquema !== "Bearer" || !token) {
    rechazar(res, "el header Authorization no tiene el formato 'Bearer <token>'");
    return;
  }

  const secret = process.env.JWT_SECRET;
  if (!secret) {
    console.error("[auth] JWT_SECRET no está configurado en el servidor");
    res.status(500).json({ error: "Error interno del servidor" });
    return;
  }

  try {
    const payload = jwt.verify(token, secret);

    if (!esAuthTokenPayload(payload)) {
      rechazar(res, "el token es válido pero su contenido no tiene el formato esperado");
      return;
    }

    req.user = payload;
    next();
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      rechazar(res, "el token está vencido");
      return;
    }
    if (err instanceof jwt.JsonWebTokenError) {
      rechazar(res, `el token es inválido o fue manipulado (${err.message})`);
      return;
    }
    rechazar(res, "error inesperado verificando el token");
  }
}
