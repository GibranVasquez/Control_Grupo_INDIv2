import { Router } from "express";
import * as solicitudController from "../controllers/solicitudAutorizacion.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";

export const solicitudAutorizacionRouter = Router();

solicitudAutorizacionRouter.use(authMiddleware);

// Solo el chofer crea sus propias solicitudes.
solicitudAutorizacionRouter.post("/", permitirRoles("chofer"), solicitudController.crear);

solicitudAutorizacionRouter.get("/", solicitudController.listarPorChofer);

// Bandeja de pendientes por obra: administrativo (su obra) y finanzas (todas).
solicitudAutorizacionRouter.get(
  "/pendientes",
  permitirRoles("administrativo", "finanzas"),
  solicitudController.listarPendientesPorObra
);

// Autorizar/rechazar: solo administrativo.
solicitudAutorizacionRouter.put(
  "/:id/resolver",
  permitirRoles("administrativo"),
  solicitudController.resolver
);
