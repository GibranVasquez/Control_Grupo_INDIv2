import { Router } from "express";
import { authRouter } from "./auth.routes";
import { vehiculoRouter } from "./vehiculo.routes";
import { obraRouter } from "./obra.routes";
import { cargaRouter } from "./carga.routes";
import { solicitudAutorizacionRouter } from "./solicitudAutorizacion.routes";
import { precioCombustibleRouter } from "./precioCombustible.routes";
import { semanaOperativaRouter } from "./semanaOperativa.routes";
import { reportesRouter } from "./reportes.routes";

export const router = Router();

router.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

router.use("/auth", authRouter);
router.use("/vehiculos", vehiculoRouter);
router.use("/obras", obraRouter);
router.use("/cargas", cargaRouter);
router.use("/solicitudes-autorizacion", solicitudAutorizacionRouter);
router.use("/precios-combustible", precioCombustibleRouter);
router.use("/semanas-operativas", semanaOperativaRouter);
router.use("/reportes", reportesRouter);
