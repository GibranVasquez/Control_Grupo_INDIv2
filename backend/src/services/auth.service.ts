import bcrypt from "bcrypt";
import jwt, { SignOptions } from "jsonwebtoken";
import { Perfil } from "@prisma/client";
import { prisma } from "../utils/prisma";
import { AppError } from "../utils/AppError";
import { serializarPerfil, PerfilPublico } from "../utils/perfilSerializer";

const MENSAJE_CREDENCIALES_INVALIDAS = "Número de empleado o contraseña incorrectos.";
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
  numeroEmpleado: string,
  password: string
): Promise<ResultadoLogin> {
  const perfil = await prisma.perfil.findUnique({
    where: { numeroEmpleado },
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
