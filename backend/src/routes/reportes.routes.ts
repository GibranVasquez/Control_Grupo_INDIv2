import { Router } from "express";
import * as reportesController from "../controllers/reportes.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";

export const reportesRouter = Router();

reportesRouter.use(authMiddleware);

// Reportes: solo lectura, administrativo (su obra) y finanzas (todas).
reportesRouter.get(
  "/concentrado-cargas",
  permitirRoles("administrativo", "finanzas"),
  reportesController.concentradoCargas
);

reportesRouter.get(
  "/resumen-financiero-semanal",
  permitirRoles("administrativo", "finanzas"),
  reportesController.resumenFinancieroSemanal
);

reportesRouter.get(
  "/resumen-financiero-consolidado",
  permitirRoles("finanzas"),
  reportesController.resumenFinancieroConsolidado
);

// Cualquier rol autenticado puede consultar el consumo de un vehículo
// (el chofer suele revisarlo antes de pedir más combustible); el service
// valida que sea de su propia obra.
reportesRouter.get(
  "/consumo-vehiculo-semanal/:vehiculoId",
  reportesController.consumoSemanalDeVehiculo
);
