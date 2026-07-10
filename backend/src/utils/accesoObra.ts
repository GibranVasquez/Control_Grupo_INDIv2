import { AuthTokenPayload } from "../types/auth";
import { AppError } from "./AppError";

/**
 * chofer/administrativo solo acceden a datos de su propia obra; finanzas ve todo.
 * Responde 403 (no 404) para no revelar si el recurso existe en otra obra.
 */
export function asegurarAccesoObra(user: AuthTokenPayload, obraId: string | null): void {
  if (user.rol === "finanzas") return;
  if (obraId === null || user.obraId !== obraId) {
    throw new AppError(403, "No tienes acceso a los recursos de esta obra.");
  }
}
