import "dotenv/config";
import crypto from "crypto";
import bcrypt from "bcrypt";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@prisma/client";

// ---------------------------------------------------------------------
// Rota la contraseña "1234" (solo dev/pruebas) de los 3 perfiles semilla por
// una contraseña aleatoria distinta para cada uno. Pensado para correrse UNA
// VEZ, a mano, cuando frontend ya no dependa de "1234" para sus pruebas.
//
// Uso:
//   npx ts-node prisma/rotar-passwords.ts
//
// Las contraseñas nuevas se imprimen en consola una sola vez al terminar.
// Este script NO las guarda en ningún archivo ni las vuelve a mostrar
// después: si se pierden, hay que volver a correr el script (lo cual rota
// las contraseñas otra vez).
// ---------------------------------------------------------------------

const NUMEROS_EMPLEADO = ["EMP-1001", "EMP-2001", "EMP-3001"] as const;

const ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*";

/** Contraseña aleatoria de `longitud` caracteres, usando crypto.randomInt
 * (no Math.random) para que la selección de cada carácter sea criptográficamente segura. */
function generarPasswordSegura(longitud = 20): string {
  let password = "";
  for (let i = 0; i < longitud; i++) {
    password += ALFABETO[crypto.randomInt(ALFABETO.length)];
  }
  return password;
}

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

async function main() {
  const resultados: { usuario: string; passwordNueva: string }[] = [];

  for (const usuario of NUMEROS_EMPLEADO) {
    const perfil = await prisma.perfil.findUnique({ where: { usuario } });
    if (!perfil) {
      console.warn(`Aviso: no existe un perfil con usuario=${usuario}, se omite.`);
      continue;
    }

    const passwordNueva = generarPasswordSegura();
    const passwordHash = await bcrypt.hash(passwordNueva, 10);
    await prisma.perfil.update({ where: { id: perfil.id }, data: { passwordHash } });
    resultados.push({ usuario, passwordNueva });
  }

  console.log("\n=== Contraseñas nuevas (guárdalas ahora; no se van a volver a mostrar) ===");
  for (const { usuario, passwordNueva } of resultados) {
    console.log(`${usuario}: ${passwordNueva}`);
  }
  console.log("===========================================================================\n");
}

main()
  .catch((err) => {
    console.error("Error rotando contraseñas:", err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
