import { Router } from "express";
import * as semanaController from "../controllers/semanaOperativa.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";

export const semanaOperativaRouter = Router();

semanaOperativaRouter.use(authMiddleware);

semanaOperativaRouter.get("/actual", semanaController.obtenerActual);

// Cerrar la semana es una acción administrativa/financiera, no de chofer.
semanaOperativaRouter.put(
  "/:id/cerrar",
  permitirRoles("administrativo", "finanzas"),
  semanaController.cerrar
);
