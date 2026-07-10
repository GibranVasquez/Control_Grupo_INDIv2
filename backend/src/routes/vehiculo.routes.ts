import { Router } from "express";
import * as vehiculoController from "../controllers/vehiculo.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";

export const vehiculoRouter = Router();

vehiculoRouter.use(authMiddleware);

// Lectura: chofer y administrativo (su obra, validado en el service), finanzas (todas).
vehiculoRouter.get("/", vehiculoController.listarPorObra);
vehiculoRouter.get("/:id", vehiculoController.obtenerPorId);

// Escritura: solo administrativo. finanzas es de solo lectura en este catálogo.
vehiculoRouter.post("/", permitirRoles("administrativo"), vehiculoController.crear);
vehiculoRouter.put("/:id", permitirRoles("administrativo"), vehiculoController.actualizar);
