import fs from "fs";
import path from "path";
import crypto from "crypto";
import multer from "multer";
import { AppError } from "../utils/AppError";

const TIPOS_PERMITIDOS = ["image/jpeg", "image/png", "image/webp"];
const TAMANO_MAXIMO_BYTES = 10 * 1024 * 1024; // 10 MB

const DIRECTORIO_TICKETS = path.join(__dirname, "..", "..", "uploads", "tickets");
fs.mkdirSync(DIRECTORIO_TICKETS, { recursive: true });

const storage = multer.diskStorage({
  destination: DIRECTORIO_TICKETS,
  filename: (_req, file, cb) => {
    const extension = path.extname(file.originalname);
    cb(null, `${crypto.randomUUID()}${extension}`);
  },
});

export const uploadFotoTicket = multer({
  storage,
  limits: { fileSize: TAMANO_MAXIMO_BYTES },
  fileFilter: (_req, file, cb) => {
    if (!TIPOS_PERMITIDOS.includes(file.mimetype)) {
      cb(new AppError(400, "El ticket debe ser una imagen JPEG, PNG o WebP."));
      return;
    }
    cb(null, true);
  },
}).single("foto");
