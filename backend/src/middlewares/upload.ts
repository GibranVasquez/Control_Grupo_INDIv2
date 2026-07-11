import multer from "multer";
import { AppError } from "../utils/AppError";

const TIPOS_PERMITIDOS = ["image/jpeg", "image/png", "image/webp"];
const TAMANO_MAXIMO_BYTES = 10 * 1024 * 1024; // 10 MB

// memoryStorage (no diskStorage): el archivo llega como buffer en
// req.file.buffer y carga.controller.ts lo entrega a storageService, que
// decide si se escribe a disco o a S3/R2 según STORAGE_PROVIDER.
export const uploadFotoTicket = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: TAMANO_MAXIMO_BYTES },
  fileFilter: (_req, file, cb) => {
    if (!TIPOS_PERMITIDOS.includes(file.mimetype)) {
      cb(new AppError(400, "El ticket debe ser una imagen JPEG, PNG o WebP."));
      return;
    }
    cb(null, true);
  },
}).single("foto");
