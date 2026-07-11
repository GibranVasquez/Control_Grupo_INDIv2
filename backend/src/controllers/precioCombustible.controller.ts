import { Request, Response } from "express";
import * as precioService from "../services/precioCombustible.service";
import { paramString } from "../utils/validacion";

export async function obtenerVigente(req: Request, res: Response): Promise<void> {
  const precio = await precioService.obtenerVigente(req.query.tipo);
  res.json({ precio });
}

export async function listarHistorico(req: Request, res: Response): Promise<void> {
  const precios = await precioService.listarHistorico(req.query.tipo);
  res.json({ precios });
}

export async function listar(req: Request, res: Response): Promise<void> {
  const soloVigentes = req.query.vigente === "true";
  const precios = await precioService.listar(soloVigentes);
  res.json({ precios });
}

export async function crear(req: Request, res: Response): Promise<void> {
  const precio = await precioService.crear(req.user!, req.body ?? {});
  res.status(201).json({ precio });
}

export async function actualizar(req: Request, res: Response): Promise<void> {
  const precio = await precioService.actualizar(paramString(req.params.id), req.body ?? {});
  res.json({ precio });
}
