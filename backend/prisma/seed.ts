import "dotenv/config";
import bcrypt from "bcrypt";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@prisma/client";

// ---------------------------------------------------------------------
// ADVERTENCIA: la contraseña "1234" es SOLO para desarrollo/pruebas locales.
// NUNCA usar esta contraseña (ni un hash generado a partir de ella) en un
// ambiente de producción o con datos reales.
// ---------------------------------------------------------------------
const PASSWORD_DEV_INSEGURA = "1234";

// IDs insertados por migracion_grupo_indi.sql (sección 11: datos semilla).
const OBRA_LOS_PINOS_ID = "a1000000-0000-0000-0000-000000000001";
const VEHICULO_FORD_F150_ID = "b2000000-0000-0000-0000-000000000001";

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

async function main() {
  const passwordHash = bcrypt.hashSync(PASSWORD_DEV_INSEGURA, 10);

  const perfiles = [
    {
      usuario: "mario",
      nombreCompleto: "Juan Pérez",
      rol: "chofer" as const,
      obraId: OBRA_LOS_PINOS_ID,
      vehiculoId: VEHICULO_FORD_F150_ID,
    },
    {
      usuario: "laura",
      nombreCompleto: "María López",
      rol: "administrativo" as const,
      obraId: OBRA_LOS_PINOS_ID,
      vehiculoId: null,
    },
    {
      usuario: "andrea",
      nombreCompleto: "Carlos Ruiz",
      rol: "finanzas" as const,
      obraId: null,
      vehiculoId: null,
    },
  ];

  for (const datos of perfiles) {
    const perfil = await prisma.perfil.upsert({
      where: { usuario: datos.usuario },
      update: {
        nombreCompleto: datos.nombreCompleto,
        rol: datos.rol,
        obraId: datos.obraId,
        vehiculoId: datos.vehiculoId,
        passwordHash,
        activo: true,
      },
      create: {
        usuario: datos.usuario,
        nombreCompleto: datos.nombreCompleto,
        rol: datos.rol,
        obraId: datos.obraId,
        vehiculoId: datos.vehiculoId,
        passwordHash,
      },
    });
    console.log(`Perfil listo: ${perfil.usuario} (${perfil.rol})`);
  }
}

main()
  .catch((err) => {
    console.error("Error corriendo el seed:", err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
