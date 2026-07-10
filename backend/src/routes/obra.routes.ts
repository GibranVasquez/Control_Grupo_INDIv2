import { Router } from "express";
import * as obraController from "../controllers/obra.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";

export const obraRouter = Router();

obraRouter.use(authMiddleware);

// Solo finanzas ve el listado completo de obras (no está atado a una sola).
obraRouter.get("/", permitirRoles("finanzas"), obraController.listarTodas);
obraRouter.get("/:id", obraController.obtenerPorId);
