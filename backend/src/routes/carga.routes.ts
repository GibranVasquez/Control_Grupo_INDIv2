import { Router } from "express";
import * as cargaController from "../controllers/carga.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";
import { uploadFotoTicket } from "../middlewares/upload";

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
