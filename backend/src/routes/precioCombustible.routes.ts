import { Router } from "express";
import * as precioController from "../controllers/precioCombustible.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";

export const precioCombustibleRouter = Router();

precioCombustibleRouter.use(authMiddleware);

precioCombustibleRouter.get("/vigente", precioController.obtenerVigente);
precioCombustibleRouter.get("/historico", precioController.listarHistorico);

// Solo finanzas da de alta un nuevo precio vigente.
precioCombustibleRouter.post("/", permitirRoles("finanzas"), precioController.crear);
