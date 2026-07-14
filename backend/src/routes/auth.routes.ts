import { Router } from "express";
import { login, perfilActual, registro } from "../controllers/auth.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { limitadorLogin, limitadorRegistro } from "../middlewares/rateLimit";
import { validarLogin } from "../middlewares/validarLogin";

export const authRouter = Router();

authRouter.post("/login", limitadorLogin, validarLogin, login);
// Autoregistro público de chofer: sin authMiddleware (no hay sesión todavía),
// ver auth.service.ts#registrarChofer para las decisiones de alcance.
authRouter.post("/registro-chofer", limitadorRegistro, registro);
authRouter.get("/perfil-actual", authMiddleware, perfilActual);
