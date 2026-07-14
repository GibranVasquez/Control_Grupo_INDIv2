// Suite de permisos por rol (chofer/administrativo/finanzas). Corre contra la
// BD real configurada en backend/.env (ver seed.ts para los perfiles usados
// aquí: EMP-1001 chofer, EMP-2001 administrativo, ambos de la obra "Los
// Pinos"; EMP-3001 finanzas, sin obra). No crea ni modifica datos: todas las
// aserciones son de autorización (401/403/200 antes de tocar la BD para
// escritura), así que es seguro correrla repetidamente sin ensuciar la BD
// compartida.
import { beforeAll, describe, expect, it } from "vitest";
import request from "supertest";
import { app } from "../app";

const OBRA_LOS_PINOS_ID = "a1000000-0000-0000-0000-000000000001";
const OBRA_PLAZA_NORTE_ID = "a1000000-0000-0000-0000-000000000002";
const VEHICULO_OBRA_PLAZA_NORTE_ID = "b2000000-0000-0000-0000-000000000003";

async function login(usuario: string): Promise<string> {
  const respuesta = await request(app)
    .post("/auth/login")
    .send({ numero_empleado: usuario, password: "1234" });
  if (respuesta.status !== 200) {
    throw new Error(
      `No se pudo iniciar sesión con ${usuario}: ${respuesta.status} ${JSON.stringify(respuesta.body)}`
    );
  }
  return respuesta.body.token as string;
}

describe("permisos por rol", () => {
  let tokenChofer: string;
  let tokenAdministrativo: string;
  let tokenFinanzas: string;

  it("login con contraseña incorrecta responde 401", async () => {
    const respuesta = await request(app)
      .post("/auth/login")
      .send({ numero_empleado: "EMP-1001", password: "contraseña-incorrecta" });
    expect(respuesta.status).toBe(401);
  });

  beforeAll(async () => {
    tokenChofer = await login("EMP-1001");
    tokenAdministrativo = await login("EMP-2001");
    tokenFinanzas = await login("EMP-3001");
  });

  it("sin token, una ruta protegida responde 401", async () => {
    const respuesta = await request(app).get("/vehiculos");
    expect(respuesta.status).toBe(401);
  });

  it("token inválido/manipulado responde 401", async () => {
    const respuesta = await request(app)
      .get("/vehiculos")
      .set("Authorization", "Bearer token-que-no-existe");
    expect(respuesta.status).toBe(401);
  });

  it("chofer no puede dar de alta un vehículo (solo administrativo)", async () => {
    const respuesta = await request(app)
      .post("/vehiculos")
      .set("Authorization", `Bearer ${tokenChofer}`)
      .send({ placa: "XX-99-999", marca: "Test", modelo: "Test", anio: 2024 });
    expect(respuesta.status).toBe(403);
  });

  it("chofer no puede dar de alta un precio de combustible (solo finanzas)", async () => {
    const respuesta = await request(app)
      .post("/precios-combustible")
      .set("Authorization", `Bearer ${tokenChofer}`)
      .send({ tipo_combustible: "magna", precio_por_litro: 24 });
    expect(respuesta.status).toBe(403);
  });

  it("administrativo no puede dar de alta un precio de combustible (solo finanzas)", async () => {
    const respuesta = await request(app)
      .post("/precios-combustible")
      .set("Authorization", `Bearer ${tokenAdministrativo}`)
      .send({ tipo_combustible: "magna", precio_por_litro: 24 });
    expect(respuesta.status).toBe(403);
  });

  it("administrativo no puede listar todas las obras (solo finanzas)", async () => {
    const respuesta = await request(app)
      .get("/obras")
      .set("Authorization", `Bearer ${tokenAdministrativo}`);
    expect(respuesta.status).toBe(403);
  });

  it("finanzas sí puede listar todas las obras", async () => {
    const respuesta = await request(app)
      .get("/obras")
      .set("Authorization", `Bearer ${tokenFinanzas}`);
    expect(respuesta.status).toBe(200);
    expect(Array.isArray(respuesta.body.obras)).toBe(true);
  });

  it("chofer no puede leer una obra que no es la suya (cruce entre obras)", async () => {
    const respuesta = await request(app)
      .get(`/obras/${OBRA_PLAZA_NORTE_ID}`)
      .set("Authorization", `Bearer ${tokenChofer}`);
    expect(respuesta.status).toBe(403);
  });

  it("chofer sí puede leer su propia obra", async () => {
    const respuesta = await request(app)
      .get(`/obras/${OBRA_LOS_PINOS_ID}`)
      .set("Authorization", `Bearer ${tokenChofer}`);
    expect(respuesta.status).toBe(200);
  });

  it("chofer no puede leer un vehículo de otra obra (cruce entre obras)", async () => {
    const respuesta = await request(app)
      .get(`/vehiculos/${VEHICULO_OBRA_PLAZA_NORTE_ID}`)
      .set("Authorization", `Bearer ${tokenChofer}`);
    expect(respuesta.status).toBe(403);
  });

  it("chofer no puede resolver solicitudes de autorización (solo administrativo)", async () => {
    const respuesta = await request(app)
      .put("/solicitudes-autorizacion/00000000-0000-0000-0000-000000000000/resolver")
      .set("Authorization", `Bearer ${tokenChofer}`)
      .send({ estado: "autorizado", litros_autorizados: 10 });
    expect(respuesta.status).toBe(403);
  });

  it("chofer no puede ver la bandeja de solicitudes pendientes (administrativo/finanzas)", async () => {
    const respuesta = await request(app)
      .get("/solicitudes-autorizacion/pendientes")
      .set("Authorization", `Bearer ${tokenChofer}`);
    expect(respuesta.status).toBe(403);
  });

  it("administrativo no puede crear una solicitud de autorización (solo chofer)", async () => {
    const respuesta = await request(app)
      .post("/solicitudes-autorizacion")
      .set("Authorization", `Bearer ${tokenAdministrativo}`)
      .send({ vehiculo_id: VEHICULO_OBRA_PLAZA_NORTE_ID, litros_solicitados: 10 });
    expect(respuesta.status).toBe(403);
  });
});
