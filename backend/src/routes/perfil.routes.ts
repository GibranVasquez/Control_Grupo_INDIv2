import { Router } from "express";
import * as perfilController from "../controllers/perfil.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";

export const perfilRouter = Router();

perfilRouter.use(authMiddleware);

// Solo administrativo (su obra, validado en el service) y finanzas (sin
// restricción de obra) pueden activar/desactivar el acceso de un perfil.
perfilRouter.put("/:id/activo", permitirRoles("administrativo", "finanzas"), perfilController.actualizarActivo);

// Alta de choferes (administrativo/finanzas). No existe alta de administrativo/finanzas
// por este endpoint: esos roles ya tienen su usuario y contraseña exclusivo (ver
// perfil.service.ts crear()).
perfilRouter.post("/", permitirRoles("administrativo", "finanzas"), perfilController.crear);
