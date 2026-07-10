import { Request, Response } from "express";
import * as precioService from "../services/precioCombustible.service";

export async function obtenerVigente(req: Request, res: Response): Promise<void> {
  const precio = await precioService.obtenerVigente(req.query.tipo);
  res.json({ precio });
}

export async function listarHistorico(req: Request, res: Response): Promise<void> {
  const precios = await precioService.listarHistorico(req.query.tipo);
  res.json({ precios });
}

export async function crear(req: Request, res: Response): Promise<void> {
  const precio = await precioService.crear(req.user!, req.body ?? {});
  res.status(201).json({ precio });
}
