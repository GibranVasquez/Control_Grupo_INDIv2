import { Request, Response } from "express";
import * as obraService from "../services/obra.service";
import { paramString } from "../utils/validacion";

export async function listarTodas(_req: Request, res: Response): Promise<void> {
  const obras = await obraService.listarTodas();
  res.json({ obras });
}

export async function obtenerPorId(req: Request, res: Response): Promise<void> {
  const obra = await obraService.obtenerPorId(req.user!, paramString(req.params.id));
  res.json({ obra });
}
