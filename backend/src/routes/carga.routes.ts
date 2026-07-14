import { Router } from "express";
import * as cargaController from "../controllers/carga.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";
import { uploadEvidencias, uploadFotoTicket } from "../middlewares/upload";

export const cargaRouter = Router();

cargaRouter.use(authMiddleware);

// Solo el chofer registra sus propias cargas.
cargaRouter.post("/", permitirRoles("chofer"), cargaController.crear);

cargaRouter.get("/por-obra", cargaController.listarPorObra);
cargaRouter.get("/", cargaController.listarPorChofer);

cargaRouter.post(
  "/:id/foto-ticket",
  permitirRoles("chofer"),
  uploadFotoTicket,
  cargaController.subirFotoTicket
);

// Fotos de evidencia múltiple (Maquinaria) — complementa /foto-ticket
// (Vehículo, foto única), que se deja intacto.
cargaRouter.post(
  "/:id/evidencias",
  permitirRoles("chofer"),
  uploadEvidencias,
  cargaController.subirEvidencias
);
cargaRouter.get("/:id/evidencias", cargaController.listarEvidencias);
