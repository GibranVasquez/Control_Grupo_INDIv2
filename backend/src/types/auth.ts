import { RolUsuario } from "@prisma/client";

export interface AuthTokenPayload {
  perfilId: string;
  rol: RolUsuario;
  obraId: string | null;
  // Presente desde que el JWT también se usa para autenticar contra PowerSync
  // (ver backend/powersync/); no todos los tokens antiguos lo tendrán.
  vehiculoId?: string | null;
}

export function esAuthTokenPayload(payload: unknown): payload is AuthTokenPayload {
  return (
    typeof payload === "object" &&
    payload !== null &&
    typeof (payload as AuthTokenPayload).perfilId === "string" &&
    typeof (payload as AuthTokenPayload).rol === "string"
  );
}
