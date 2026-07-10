import { Request, Response } from "express";
import * as solicitudService from "../services/solicitudAutorizacion.service";
import { AppError } from "../utils/AppError";
import { paramString, valorDeQuery } from "../utils/validacion";

export async function crear(req: Request, res: Response): Promise<void> {
  const solicitud = await solicitudService.crear(req.user!, req.body ?? {});
  res.status(201).json({ solicitud });
}

export async function listarPorChofer(req: Request, res: Response): Promise<void> {
  const choferId = req.user!.rol === "chofer" ? req.user!.perfilId : valorDeQuery(req.query.chofer_id);
  if (!choferId) {
    throw new AppError(400, "El parámetro chofer_id es requerido.");
  }
  const solicitudes = await solicitudService.listarPorChofer(req.user!, choferId);
  res.json({ solicitudes });
}

export async function listarPendientesPorObra(req: Request, res: Response): Promise<void> {
  const obraId = valorDeQuery(req.query.obra_id);
  if (!obraId) {
    throw new AppError(400, "El parámetro obra_id es requerido.");
  }
  const solicitudes = await solicitudService.listarPendientesPorObra(req.user!, obraId);
  res.json({ solicitudes });
}

export async function resolver(req: Request, res: Response): Promise<void> {
  const solicitud = await solicitudService.resolver(req.user!, paramString(req.params.id), req.body ?? {});
  res.json({ solicitud });
}
