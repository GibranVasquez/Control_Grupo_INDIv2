import { Router } from "express";
import { login, perfilActual } from "../controllers/auth.controller";
import { authMiddleware } from "../middlewares/auth.middleware";
import { limitadorLogin } from "../middlewares/rateLimit";
import { validarLogin } from "../middlewares/validarLogin";

export const authRouter = Router();

authRouter.post("/login", limitadorLogin, validarLogin, login);
authRouter.get("/perfil-actual", authMiddleware, perfilActual);
