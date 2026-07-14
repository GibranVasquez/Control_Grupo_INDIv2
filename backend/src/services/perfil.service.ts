import bcrypt from "bcrypt";
import { Prisma } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { asegurarAccesoObra } from "../utils/accesoObra";
import { serializarPerfil, PerfilPublico } from "../utils/perfilSerializer";
import { esStringNoVacia } from "../utils/validacion";
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

const RONDAS_BCRYPT = 10;

export interface DatosCrearPerfil {
  nombre_completo: unknown;
  numero_empleado: unknown;
  password: unknown;
  obra_id: unknown;
  vehiculo_id?: unknown;
  area?: unknown;
}

/**
 * Alta de un chofer (única forma en la que un administrativo/finanzas puede dar de alta
 * un usuario, ver perfil.routes.ts): administrativo/finanzas ya tienen su propio usuario
 * y contraseña, dados de alta directo en la base de datos, no por este endpoint.
 */
export async function crear(user: AuthTokenPayload, datos: DatosCrearPerfil): Promise<PerfilPublico> {
  if (!esStringNoVacia(datos.nombre_completo, 200)) {
    throw new AppError(400, "nombre_completo es requerido y debe ser un texto válido.");
  }
  if (!esStringNoVacia(datos.numero_empleado, 100)) {
    throw new AppError(400, "numero_empleado es requerido y debe ser un texto válido.");
  }
  if (!esStringNoVacia(datos.password, 200) || (datos.password as string).length < 4) {
    throw new AppError(400, "password es requerido y debe tener al menos 4 caracteres.");
  }
  if (!esStringNoVacia(datos.obra_id, 100)) {
    throw new AppError(400, "obra_id es requerido y debe ser un texto válido.");
  }
  if (datos.vehiculo_id !== undefined && datos.vehiculo_id !== null && !esStringNoVacia(datos.vehiculo_id, 100)) {
    throw new AppError(400, "vehiculo_id debe ser un texto válido.");
  }
  if (datos.area !== undefined && datos.area !== null && !esStringNoVacia(datos.area, 100)) {
    throw new AppError(400, "area debe ser un texto válido.");
  }

  // administrativo solo puede dar de alta choferes en su propia obra; finanzas en cualquiera.
  asegurarAccesoObra(user, datos.obra_id as string);

  const obra = await prisma.obra.findUnique({ where: { id: datos.obra_id as string } });
  if (!obra) {
    throw new AppError(400, "obra_id no corresponde a una obra existente.");
  }
  if (datos.vehiculo_id) {
    const vehiculo = await prisma.vehiculo.findUnique({ where: { id: datos.vehiculo_id as string } });
    // Un solo mensaje para "no existe" y "existe pero es de otra obra": mismo
    // criterio que accesoObra.ts (no confirmar la existencia de un recurso
    // fuera del alcance del usuario) — antes se distinguían los dos casos,
    // lo que permitía a un administrativo enumerar vehículos de otras obras.
    if (!vehiculo || vehiculo.obraId !== datos.obra_id) {
      throw new AppError(400, "vehiculo_id no corresponde a un vehículo válido para esta obra.");
    }
  }

  const passwordHash = await bcrypt.hash(datos.password as string, RONDAS_BCRYPT);

  try {
    const perfil = await prisma.perfil.create({
      data: {
        numeroEmpleado: datos.numero_empleado as string,
        passwordHash,
        nombreCompleto: datos.nombre_completo as string,
        rol: "chofer",
        obraId: datos.obra_id as string,
        vehiculoId: (datos.vehiculo_id as string | undefined) ?? null,
        area: (datos.area as string | undefined) ?? null,
      },
    });
    return serializarPerfil(perfil);
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      // Mensaje genérico, sin eco del numero_empleado ni distinción de en qué
      // obra vive el duplicado: numeroEmpleado es único a nivel global, así
      // que confirmar la coincidencia exacta es un oráculo para enumerar
      // personal de otras obras (mismo criterio que accesoObra.ts: no
      // revelar la existencia de un recurso fuera del alcance del usuario).
      throw new AppError(409, "No se pudo completar el alta con los datos proporcionados.");
    }
    throw error;
  }
}

export interface DatosAsignacion {
  obra_id: unknown;
  vehiculo_id?: unknown;
}

/**
 * Asigna/reasigna obra_id y vehiculo_id de un chofer existente — ej. completar
 * el alta de un chofer que se autoregistró (POST /auth/registro-chofer, ver
 * auth.service.ts#registrarChofer) y nace sin obra ni vehículo asignados.
 */
export async function actualizarAsignacion(
  user: AuthTokenPayload,
  perfilId: string,
  datos: DatosAsignacion
): Promise<PerfilPublico> {
  if (!esStringNoVacia(datos.obra_id, 100)) {
    throw new AppError(400, "obra_id es requerido y debe ser un texto válido.");
  }
  if (
    datos.vehiculo_id !== undefined &&
    datos.vehiculo_id !== null &&
    !esStringNoVacia(datos.vehiculo_id, 100)
  ) {
    throw new AppError(400, "vehiculo_id debe ser un texto válido o null.");
  }

  const perfil = await prisma.perfil.findUnique({ where: { id: perfilId } });
  if (!perfil) {
    throw new AppError(404, "Perfil no encontrado.");
  }
  if (perfil.rol !== "chofer") {
    throw new AppError(400, "Solo se puede asignar obra/vehículo a un perfil con rol chofer.");
  }

  // administrativo solo puede asignar dentro de su propia obra.
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

  if (datos.vehiculo_id) {
    const vehiculo = await prisma.vehiculo.findUnique({ where: { id: datos.vehiculo_id as string } });
    // Mismo criterio anti-enumeración que crear(): un solo mensaje para "no
    // existe" y "existe pero es de otra obra".
    if (!vehiculo || vehiculo.obraId !== datos.obra_id) {
      throw new AppError(400, "vehiculo_id no corresponde a un vehículo válido para esta obra.");
    }
  }

  const actualizado = await prisma.perfil.update({
    where: { id: perfilId },
    data: {
      obraId: datos.obra_id as string,
      vehiculoId: (datos.vehiculo_id as string | undefined) ?? null,
    },
  });
  return serializarPerfil(actualizado);
}
