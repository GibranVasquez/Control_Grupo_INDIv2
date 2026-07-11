import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { asegurarAccesoObra } from "../utils/accesoObra";
import { serializarPerfil, PerfilPublico } from "../utils/perfilSerializer";
import { AuthTokenPayload } from "../types/auth";

/**
 * Decisión de transporte (ver auditoría de frontend/lib/services/api/api_perfil_repository.dart):
 * esto va por REST directo, no por PowerSync. Es una acción administrativa
 * poco frecuente (activar/desactivar el acceso de un chofer u otro perfil),
 * hecha normalmente con buena señal desde la app de administrativo/finanzas;
 * no vale la pena que PowerSync tenga que encolarla offline (a diferencia de
 * solicitudes_autorizacion o cargas, que sí son offline-first por
 * necesidad). El cambio de `activo` llega de vuelta al catálogo local de
 * PowerSync en la siguiente sincronización normal, igual que con
 * vehiculos.crear/actualizar.
 */
export async function actualizarActivo(
  user: AuthTokenPayload,
  perfilId: string,
  activo: unknown
): Promise<PerfilPublico> {
  if (typeof activo !== "boolean") {
    throw new AppError(400, "activo debe ser un booleano.");
  }

  const perfil = await prisma.perfil.findUnique({ where: { id: perfilId } });
  if (!perfil) {
    throw new AppError(404, "Perfil no encontrado.");
  }

  // administrativo solo puede activar/desactivar perfiles de su propia obra
  // (sus choferes); finanzas no tiene obra propia y por tanto puede sobre
  // cualquier perfil (mismo criterio que el resto de accesoObra.ts).
  asegurarAccesoObra(user, perfil.obraId);

  // Nadie puede desactivarse a sí mismo: evita que un administrativo se
  // quede sin acceso por error y ya no pueda revertirlo.
  if (perfilId === user.perfilId && !activo) {
    throw new AppError(400, "No puedes desactivar tu propia cuenta.");
  }

  const actualizado = await prisma.perfil.update({
    where: { id: perfilId },
    data: { activo },
  });
  return serializarPerfil(actualizado);
}
