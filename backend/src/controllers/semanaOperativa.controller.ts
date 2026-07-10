import { Request, Response } from "express";
import * as semanaService from "../services/semanaOperativa.service";
import { paramString, valorDeQuery } from "../utils/validacion";

export async function obtenerActual(req: Request, res: Response): Promise<void> {
  const semana = await semanaService.obtenerActual(req.user!, valorDeQuery(req.query.obra_id));
  res.json({ semana });
}

export async function cerrar(req: Request, res: Response): Promise<void> {
  const semana = await semanaService.cerrar(req.user!, paramString(req.params.id));
  res.json({ semana });
}
