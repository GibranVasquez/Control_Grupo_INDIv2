import { Request, Response } from "express";
import * as cargaService from "../services/carga.service";
import { storageService } from "../services/storage.service";
import { AppError } from "../utils/AppError";
import { paramString, valorDeQuery } from "../utils/validacion";

export async function crear(req: Request, res: Response): Promise<void> {
  const carga = await cargaService.crear(req.user!, req.body ?? {});
  res.status(201).json({ carga });
}

export async function listarPorChofer(req: Request, res: Response): Promise<void> {
  const choferId = req.user!.rol === "chofer" ? req.user!.perfilId : valorDeQuery(req.query.chofer_id);
  if (!choferId) {
    throw new AppError(400, "El parámetro chofer_id es requerido.");
  }
  const cargas = await cargaService.listarPorChofer(req.user!, choferId);
  res.json({ cargas });
}

export async function listarPorObra(req: Request, res: Response): Promise<void> {
  const obraId = valorDeQuery(req.query.obra_id);
  if (!obraId) {
    throw new AppError(400, "El parámetro obra_id es requerido.");
  }
  const cargas = await cargaService.listarPorObra(req.user!, obraId);
  res.json({ cargas });
}

export async function subirFotoTicket(req: Request, res: Response): Promise<void> {
  if (!req.file) {
    throw new AppError(400, "El archivo 'foto' es requerido.");
  }
  const key = await storageService.subirArchivo("tickets", {
    buffer: req.file.buffer,
    nombreOriginal: req.file.originalname,
    mimeType: req.file.mimetype,
  });
  const urlPublica = storageService.obtenerUrl(key);
  const carga = await cargaService.subirFotoTicket(req.user!, paramString(req.params.id), urlPublica);
  res.json({ carga });
}
