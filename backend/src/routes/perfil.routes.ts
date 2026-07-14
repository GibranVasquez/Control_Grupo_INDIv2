import { Router } from "express";
import * as perfilController from "../controllers/perfil.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { permitirRoles } from "../middlewares/role.middleware";

export const perfilRouter = Router();

perfilRouter.use(authMiddleware);

// Solo administrativo (su obra, validado en el service) y finanzas (sin
// restricción de obra) pueden activar/desactivar el acceso de un perfil.
perfilRouter.put("/:id/activo", permitirRoles("administrativo", "finanzas"), perfilController.actualizarActivo);

// Edición completa de un chofer ya autoregistrado (nombre, correo, edad,
// area, obra, vehículo). No existe alta de chofer por esta vía: el chofer se
// da de alta a sí mismo (POST /auth/registro-chofer); administrativo/
// finanzas solo completan o corrigen los datos que el chofer ya capturó, ver
// perfil.service.ts#actualizar.
perfilRouter.put("/:id", permitirRoles("administrativo", "finanzas"), perfilController.actualizar);
