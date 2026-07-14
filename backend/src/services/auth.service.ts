import bcrypt from "bcrypt";
import jwt, { SignOptions } from "jsonwebtoken";
import { Perfil, Prisma } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { serializarPerfil, PerfilPublico } from "../utils/perfilSerializer";
import {
  esCorreoValido,
  esEnteroNoNegativo,
  esPasswordValida,
  esStringNoVacia,
  esUsuarioValido,
  normalizarCorreo,
} from "../utils/validacion";

const MENSAJE_CREDENCIALES_INVALIDAS = "Usuario o contraseña incorrectos.";
const MENSAJE_CUENTA_DESACTIVADA = "Esta cuenta está desactivada. Contacta a un administrador.";

/**
 * Hash bcrypt "señuelo": no corresponde a ninguna cuenta real. Se usa para
 * comparar cuando el número de empleado no existe, de modo que bcrypt.compare
 * siempre haga el mismo trabajo y el tiempo de respuesta no delate si la
 * cuenta existe o no.
 */
const HASH_SENUELO = "$2b$10$QeLVFdXFB.dtJHFDCkGz4eDzTsAC3U9Cv/lbNNddamN/3RT28TLdu";

export interface ResultadoLogin {
  token: string;
  perfil: PerfilPublico;
}

function firmarToken(perfil: Perfil): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    // No hay valor por defecto para el secreto: preferimos que el servidor
    // falle a arrancar mal configurado antes que firmar tokens inseguros.
    throw new Error("JWT_SECRET no está configurado");
  }

  const expiresIn = (process.env.JWT_EXPIRES_IN || "1d") as SignOptions["expiresIn"];

  // sub/aud/kid solo se usan para que PowerSync (self-hosted) valide este mismo
  // JWT contra su config de client_auth (ver backend/powersync/). Son opcionales:
  // si no están configurados, el token sigue siendo válido para esta API, solo
  // que PowerSync no lo aceptaría.
  const opciones: SignOptions = { expiresIn, subject: perfil.id };
  if (process.env.POWERSYNC_JWT_AUDIENCE) {
    opciones.audience = process.env.POWERSYNC_JWT_AUDIENCE;
  }
  if (process.env.POWERSYNC_JWT_KID) {
    opciones.keyid = process.env.POWERSYNC_JWT_KID;
  }

  return jwt.sign(
    {
      perfilId: perfil.id,
      rol: perfil.rol,
      obraId: perfil.obraId,
      vehiculoId: perfil.vehiculoId,
    },
    secret,
    opciones
  );
}

export async function iniciarSesion(
  usuario: string,
  password: string
): Promise<ResultadoLogin> {
  const perfil = await prisma.perfil.findUnique({
    where: { usuario },
  });

  // bcrypt.compare corre siempre, exista o no el perfil, contra un hash real
  // en ambos casos (el del perfil o el señuelo) para no filtrar por timing
  // si el número de empleado existe.
  const passwordValida = await bcrypt.compare(password, perfil?.passwordHash ?? HASH_SENUELO);

  if (!perfil || !passwordValida) {
    // Mismo mensaje y mismo status para "no existe" y "contraseña incorrecta":
    // nunca revelar cuál de los dos fue.
    throw new AppError(401, MENSAJE_CREDENCIALES_INVALIDAS);
  }

  if (!perfil.activo) {
    // Solo se llega aquí con contraseña correcta; aun así se rechaza.
    throw new AppError(403, MENSAJE_CUENTA_DESACTIVADA);
  }

  const token = firmarToken(perfil);
  return { token, perfil: serializarPerfil(perfil) };
}

export async function obtenerPerfilPublicoPorId(perfilId: string): Promise<PerfilPublico | null> {
  const perfil = await prisma.perfil.findUnique({ where: { id: perfilId } });
  return perfil ? serializarPerfil(perfil) : null;
}

const RONDAS_BCRYPT = 10;

export interface DatosRegistroChofer {
  nombre_completo: unknown;
  usuario: unknown;
  password: unknown;
  area?: unknown;
  correo?: unknown;
  edad?: unknown;
}

/**
 * Autoregistro público de chofer (`POST /auth/registro-chofer`, ver
 * auth.routes.ts): a diferencia de perfil.service.ts#actualizar (solo
 * administrativo/finanzas, edita un chofer ya existente), este endpoint no
 * exige autenticación ni obra — el chofer queda activo de inmediato pero sin
 * obra_id/vehiculo_id asignados (nulos) hasta que un administrativo lo
 * vincule a una obra y unidad reales desde Choferes/Usuarios.
 *
 * `area` recibe el resumen de los datos que el formulario de registro pide
 * pero que el esquema de perfiles no modela todavía (correo, edad, tipo de
 * unidad, placas/número económico, obra/frente en texto libre, ingeniero al
 * que se reporta) — ver registro_chofer_page.dart. Evita perder esos datos
 * sin necesitar una migración de esquema compartida.
 */
export async function registrarChofer(datos: DatosRegistroChofer): Promise<ResultadoLogin> {
  if (!esStringNoVacia(datos.nombre_completo, 200)) {
    throw new AppError(400, "nombre_completo es requerido y debe ser un texto válido.");
  }
  if (!esUsuarioValido(datos.usuario)) {
    throw new AppError(
      400,
      "usuario es requerido, debe tener entre 3 y 30 caracteres, y solo puede contener letras, números, punto y guión bajo."
    );
  }
  if (!esPasswordValida(datos.password)) {
    throw new AppError(400, "password es requerido y debe tener al menos 8 caracteres.");
  }
  if (datos.area !== undefined && datos.area !== null && !esStringNoVacia(datos.area, 500)) {
    throw new AppError(400, "area debe ser un texto válido.");
  }
  let correo: string | undefined;
  if (datos.correo !== undefined && datos.correo !== null) {
    if (!esCorreoValido(datos.correo)) {
      throw new AppError(400, "correo debe ser un correo electrónico válido.");
    }
    correo = normalizarCorreo(datos.correo);
  }
  if (datos.edad !== undefined && datos.edad !== null && !esEnteroNoNegativo(datos.edad)) {
    throw new AppError(400, "edad debe ser un número entero no negativo.");
  }

  const passwordHash = await bcrypt.hash(datos.password as string, RONDAS_BCRYPT);

  let perfil: Perfil;
  try {
    perfil = await prisma.perfil.create({
      data: {
        usuario: datos.usuario as string,
        passwordHash,
        nombreCompleto: datos.nombre_completo as string,
        rol: "chofer",
        area: (datos.area as string | undefined) ?? null,
        correo: correo ?? null,
        edad: (datos.edad as number | undefined) ?? null,
        activo: true,
      },
    });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      // usuario sí se hace eco (no es sensible); correo NO, para no
      // convertir este endpoint público en un oráculo de "¿este correo ya
      // está registrado?" (mismo criterio anti-enumeración que
      // perfil.service.ts#actualizar usa para vehiculo_id de otra obra).
      //
      // "numero_empleado" aquí es el nombre de la COLUMNA física en Postgres
      // (distinto ya del campo `usuario` del wire/Prisma desde la Etapa 3.5
      // del rename) — pendiente de actualizar a "usuario" cuando se aplique
      // el ALTER TABLE de la Etapa 4. Nota: en la práctica este chequeo no
      // se dispara nunca con el driver adapter actual (@prisma/adapter-pg),
      // que no llena `error.meta.target` — ver hallazgo anotado aparte, no
      // se corrige aquí.
      const campos = (error.meta?.target as string[] | undefined) ?? [];
      // Solo se hace eco del usuario cuando el conflicto es inequívocamente
      // ese campo; cualquier otro caso (correo, o formato de error
      // inesperado) usa el mensaje genérico, para no arriesgarse a confirmar
      // la existencia de un correo por una mala interpretación del error de
      // Postgres.
      if (campos.length === 1 && campos[0] === "numero_empleado") {
        throw new AppError(409, `Ya existe una cuenta con el usuario "${datos.usuario}".`);
      }
      throw new AppError(409, "No se pudo completar el registro con los datos proporcionados.");
    }
    throw error;
  }

  const token = firmarToken(perfil);
  return { token, perfil: serializarPerfil(perfil) };
}
