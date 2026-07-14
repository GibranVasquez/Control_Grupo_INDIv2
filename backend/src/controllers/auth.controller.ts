import { Request, Response } from "express";
import { iniciarSesion, obtenerPerfilPublicoPorId, registrarChofer } from "../services/auth.service";
import { AppError } from "../utils/AppError";

// Express 5 reenvía automáticamente los rechazos de promesas de handlers
// async al errorHandler, así que no hace falta try/catch aquí.

export async function login(req: Request, res: Response): Promise<void> {
  const { numero_empleado, password } = req.body;
  const resultado = await iniciarSesion(numero_empleado, password);
  res.json(resultado);
}

export async function registro(req: Request, res: Response): Promise<void> {
  const resultado = await registrarChofer(req.body ?? {});
  res.status(201).json(resultado);
}

export async function perfilActual(req: Request, res: Response): Promise<void> {
  // authMiddleware corrió antes en la ruta y garantiza req.user.
  const perfil = await obtenerPerfilPublicoPorId(req.user!.perfilId);

  if (!perfil) {
    // El perfil del token ya no existe (borrado, etc.): el token deja de ser válido.
    throw new AppError(401, "No autorizado.");
  }

  res.json({ perfil });
}
