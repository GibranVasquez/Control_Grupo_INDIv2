import { Router } from "express";
import * as precioController from "../controllers/precioCombustible.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";

export const precioCombustibleRouter = Router();

precioCombustibleRouter.use(authMiddleware);

precioCombustibleRouter.get("/vigente", precioController.obtenerVigente);
precioCombustibleRouter.get("/historico", precioController.listarHistorico);
precioCombustibleRouter.get("/", precioController.listar);

// Solo finanzas da de alta o corrige un precio.
precioCombustibleRouter.post("/", permitirRoles("finanzas"), precioController.crear);
precioCombustibleRouter.put("/:id", permitirRoles("finanzas"), precioController.actualizar);
