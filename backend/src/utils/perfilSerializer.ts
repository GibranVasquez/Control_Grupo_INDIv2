import { Perfil } from "@prisma/client";

/**
 * Shape pública del perfil expuesta al frontend. Lista explícita de claves:
 * agregar un campo a `Perfil` (ej. password_hash) nunca se filtra por accidente,
 * porque este serializador solo copia lo que aparece aquí.
 */
export interface PerfilPublico {
  id: string;
  auth_user_id: string;
  numero_empleado: string;
  nombre_completo: string;
  rol: string;
  obra_id: string | null;
  vehiculo_id: string | null;
  area: string | null;
  correo: string | null;
  edad: number | null;
  activo: boolean;
}

export function serializarPerfil(perfil: Perfil): PerfilPublico {
  return {
    id: perfil.id,
    auth_user_id: perfil.authUserId,
    numero_empleado: perfil.usuario,
    nombre_completo: perfil.nombreCompleto,
    rol: perfil.rol,
    obra_id: perfil.obraId,
    vehiculo_id: perfil.vehiculoId,
    area: perfil.area,
    correo: perfil.correo,
    edad: perfil.edad,
    activo: perfil.activo,
  };
}
