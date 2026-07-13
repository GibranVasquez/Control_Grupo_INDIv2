import { Request, Response } from "express";
import * as reportesService from "../services/reportes.service";
import { AppError } from "../utils/AppError";
import { paramString, valorDeQuery } from "../utils/validacion";

export async function concentradoCargas(req: Request, res: Response): Promise<void> {
  const obraId = valorDeQuery(req.query.obra_id);
  if (!obraId) {
    throw new AppError(400, "El parámetro obra_id es requerido.");
  }
  const filas = await reportesService.concentradoCargas(
    req.user!,
    obraId,
    req.query.desde,
    req.query.hasta,
    req.query.vehiculo_id
  );
  res.json({ cargas: filas });
}

export async function exportarConcentradoCargasExcel(req: Request, res: Response): Promise<void> {
  const obraId = valorDeQuery(req.query.obra_id);
  if (!obraId) {
    throw new AppError(400, "El parámetro obra_id es requerido.");
  }
  const filas = await reportesService.concentradoCargas(
    req.user!,
    obraId,
    req.query.desde,
    req.query.hasta,
    req.query.vehiculo_id
  );
  const workbook = reportesService.generarExcelConcentradoCargas(filas);

  res.setHeader(
    "Content-Type",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  );
  res.setHeader("Content-Disposition", 'attachment; filename="concentrado-cargas.xlsx"');
  await workbook.xlsx.write(res);
  res.end();
}

export async function resumenFinancieroSemanal(req: Request, res: Response): Promise<void> {
  const obraId = valorDeQuery(req.query.obra_id);
  if (!obraId) {
    throw new AppError(400, "El parámetro obra_id es requerido.");
  }
  const filas = await reportesService.resumenFinancieroSemanal(req.user!, obraId);
  res.json({ semanas: filas });
}

export async function resumenFinancieroConsolidado(_req: Request, res: Response): Promise<void> {
  const filas = await reportesService.resumenFinancieroConsolidado();
  res.json({ semanas: filas });
}

export async function consumoSemanalDeVehiculo(req: Request, res: Response): Promise<void> {
  const fila = await reportesService.consumoSemanalDeVehiculo(
    req.user!,
    paramString(req.params.vehiculoId)
  );
  res.json({ consumo: fila });
}

export async function fondoSemanalPorObra(req: Request, res: Response): Promise<void> {
  const obraId = valorDeQuery(req.query.obra_id);
  if (!obraId) {
    throw new AppError(400, "El parámetro obra_id es requerido.");
  }
  const semanas = await reportesService.fondoSemanalPorObra(req.user!, obraId);
  res.json({ semanas });
}
