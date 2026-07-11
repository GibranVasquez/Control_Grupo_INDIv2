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
