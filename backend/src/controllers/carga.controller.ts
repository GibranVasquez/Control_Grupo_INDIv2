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

export async function subirEvidencias(req: Request, res: Response): Promise<void> {
  const archivos = (req.files as Express.Multer.File[] | undefined) ?? [];
  if (archivos.length === 0) {
    throw new AppError(400, "Se requiere al menos un archivo en 'fotos'.");
  }

  const urlsPublicas: string[] = [];
  for (const archivo of archivos) {
    const key = await storageService.subirArchivo("evidencias", {
      buffer: archivo.buffer,
      nombreOriginal: archivo.originalname,
      mimeType: archivo.mimetype,
    });
    urlsPublicas.push(storageService.obtenerUrl(key));
  }

  const evidencias = await cargaService.subirEvidencias(req.user!, paramString(req.params.id), urlsPublicas);
  res.status(201).json({ evidencias });
}

export async function listarEvidencias(req: Request, res: Response): Promise<void> {
  const evidencias = await cargaService.listarEvidencias(req.user!, paramString(req.params.id));
  res.json({ evidencias });
}
