import { Request, Response } from "express";
import * as perfilService from "../services/perfil.service";
import { paramString } from "../utils/validacion";

export async function actualizarActivo(req: Request, res: Response): Promise<void> {
  const perfil = await perfilService.actualizarActivo(
    req.user!,
    paramString(req.params.id),
    (req.body ?? {}).activo
  );
  res.json({ perfil });
}

export async function crear(req: Request, res: Response): Promise<void> {
  const perfil = await perfilService.crear(req.user!, req.body ?? {});
  res.status(201).json({ perfil });
}

export async function actualizarAsignacion(req: Request, res: Response): Promise<void> {
  const perfil = await perfilService.actualizarAsignacion(
    req.user!,
    paramString(req.params.id),
    req.body ?? {}
  );
  res.json({ perfil });
}
