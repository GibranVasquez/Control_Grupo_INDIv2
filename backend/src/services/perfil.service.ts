import { Prisma } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { asegurarAccesoObra } from "../utils/accesoObra";
import { serializarPerfil, PerfilPublico } from "../utils/perfilSerializer";
import { esCorreoValido, esEnteroNoNegativo, esStringNoVacia, normalizarCorreo } from "../utils/validacion";
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

export interface DatosActualizarPerfil {
  obra_id: unknown;
  nombre_completo?: unknown;
  vehiculo_id?: unknown;
  area?: unknown;
  correo?: unknown;
  edad?: unknown;
}

/**
 * Edición parcial de un chofer ya existente (nombre, correo, edad, area,
 * obra, vehículo) — incluye lo que antes era "asignación" (obra_id/
 * vehiculo_id) para completar el alta de un chofer autoregistrado (POST
 * /auth/registro-chofer, ver auth.service.ts#registrarChofer), que nace sin
 * obra ni vehículo. rol y numero_empleado no son editables por esta vía:
 * rol es fijo, y numero_empleado es el identificador con el que el chofer
 * inicia sesión.
 *
 * Solo se tocan los campos presentes en `datos` (aunque vengan en `null`,
 * para poder borrar correo/area/edad/vehiculo_id a propósito); un campo
 * ausente conserva su valor actual. Única excepción: `obra_id` es
 * obligatorio en cada request, no se puede omitir.
 */
export async function actualizar(
  user: AuthTokenPayload,
  perfilId: string,
  datos: DatosActualizarPerfil
): Promise<PerfilPublico> {
  if (!esStringNoVacia(datos.obra_id, 100)) {
    throw new AppError(400, "obra_id es requerido y debe ser un texto válido.");
  }

  const perfil = await prisma.perfil.findUnique({ where: { id: perfilId } });
  if (!perfil) {
    throw new AppError(404, "Perfil no encontrado.");
  }
  if (perfil.rol !== "chofer") {
    throw new AppError(400, "Solo se puede editar por esta vía un perfil con rol chofer.");
  }

  // administrativo solo puede editar dentro de su propia obra.
  asegurarAccesoObra(user, datos.obra_id as string);
  // Si el perfil ya pertenecía a otra obra, también se exige acceso a esa obra
  // actual: evita que un administrativo mueva un chofer de otra obra hacia la
  // suya (finanzas, sin obra propia, no tiene esta restricción).
  if (perfil.obraId !== null) {
    asegurarAccesoObra(user, perfil.obraId);
  }

  const obra = await prisma.obra.findUnique({ where: { id: datos.obra_id as string } });
  if (!obra) {
    throw new AppError(400, "obra_id no corresponde a una obra existente.");
  }

  const data: Prisma.PerfilUncheckedUpdateInput = { obraId: datos.obra_id as string };

  if (datos.nombre_completo !== undefined) {
    if (!esStringNoVacia(datos.nombre_completo, 200)) {
      throw new AppError(400, "nombre_completo debe ser un texto válido.");
    }
    data.nombreCompleto = datos.nombre_completo as string;
  }

  if (datos.area !== undefined) {
    if (datos.area !== null && !esStringNoVacia(datos.area, 100)) {
      throw new AppError(400, "area debe ser un texto válido o null.");
    }
    data.area = (datos.area as string | null) ?? null;
  }

  if (datos.correo !== undefined) {
    if (datos.correo === null) {
      data.correo = null;
    } else {
      if (!esCorreoValido(datos.correo)) {
        throw new AppError(400, "correo debe ser un correo electrónico válido.");
      }
      data.correo = normalizarCorreo(datos.correo);
    }
  }

  if (datos.edad !== undefined) {
    if (datos.edad !== null && !esEnteroNoNegativo(datos.edad)) {
      throw new AppError(400, "edad debe ser un número entero no negativo.");
    }
    data.edad = (datos.edad as number | null) ?? null;
  }

  // vehiculo_id destino: el que venga en el body, o si no vino, el que ya
  // tenía el perfil (revalidado abajo por si cambió de obra sin reenviarlo).
  const vehiculoIdDestino = datos.vehiculo_id !== undefined ? datos.vehiculo_id : perfil.vehiculoId;
  if (
    datos.vehiculo_id !== undefined &&
    datos.vehiculo_id !== null &&
    !esStringNoVacia(datos.vehiculo_id, 100)
  ) {
    throw new AppError(400, "vehiculo_id debe ser un texto válido o null.");
  }

  if (vehiculoIdDestino) {
    const vehiculo = await prisma.vehiculo.findUnique({ where: { id: vehiculoIdDestino as string } });
    // Un solo mensaje para "no existe" y "existe pero es de otra obra": mismo
    // criterio que accesoObra.ts (no confirmar la existencia de un recurso
    // fuera del alcance del usuario). Se revisa incluso si vehiculo_id no
    // vino en este request, para no dejar un chofer con un vehículo de su
    // obra anterior tras cambiarlo de obra_id sin reenviar vehiculo_id.
    if (!vehiculo || vehiculo.obraId !== datos.obra_id) {
      throw new AppError(
        400,
        datos.vehiculo_id !== undefined
          ? "vehiculo_id no corresponde a un vehículo válido para esta obra."
          : "El vehículo actualmente asignado no pertenece a la nueva obra; envía vehiculo_id explícitamente."
      );
    }
  }
  if (datos.vehiculo_id !== undefined) {
    data.vehiculoId = (datos.vehiculo_id as string | null) ?? null;
  }

  try {
    const actualizado = await prisma.perfil.update({
      where: { id: perfilId },
      data,
    });
    return serializarPerfil(actualizado);
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      // Mensaje genérico, sin distinguir si chocó correo u otro campo único:
      // mismo criterio anti-enumeración que el resto del archivo.
      throw new AppError(409, "No se pudo actualizar el perfil con los datos proporcionados.");
    }
    throw error;
  }
}
