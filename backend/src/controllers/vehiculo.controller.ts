import { Request, Response } from "express";
import * as vehiculoService from "../services/vehiculo.service";
import { AppError } from "../utils/AppError";
import { paramString, valorDeQuery } from "../utils/validacion";

export async function listarPorObra(req: Request, res: Response): Promise<void> {
  const obraId = valorDeQuery(req.query.obra_id);
  if (!obraId) {
    throw new AppError(400, "El parámetro obra_id es requerido.");
  }
  const vehiculos = await vehiculoService.listarPorObra(req.user!, obraId);
  res.json({ vehiculos });
}

export async function obtenerPorId(req: Request, res: Response): Promise<void> {
  const vehiculo = await vehiculoService.obtenerPorId(req.user!, paramString(req.params.id));
  res.json({ vehiculo });
}

export async function crear(req: Request, res: Response): Promise<void> {
  const vehiculo = await vehiculoService.crear(req.user!, req.body ?? {});
  res.status(201).json({ vehiculo });
}

export async function actualizar(req: Request, res: Response): Promise<void> {
  const vehiculo = await vehiculoService.actualizar(req.user!, paramString(req.params.id), req.body ?? {});
  res.json({ vehiculo });
}
