import crypto from "crypto";
import fs from "fs";
import path from "path";
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";

export interface ArchivoParaSubir {
  buffer: Buffer;
  nombreOriginal: string;
  mimeType: string;
}

export interface StorageService {
  /** Sube el archivo dentro de `carpeta` y devuelve la key con la que luego se pide `obtenerUrl`. */
  subirArchivo(carpeta: string, archivo: ArchivoParaSubir): Promise<string>;
  /** URL pública (servida por esta misma API en local, o del bucket en S3/R2) para una key ya subida. */
  obtenerUrl(key: string): string;
}

function nombreUnico(nombreOriginal: string): string {
  return `${crypto.randomUUID()}${path.extname(nombreOriginal)}`;
}

/**
 * Fallback de desarrollo: escribe a disco bajo backend/uploads/. Se pierde en
 * cada redeploy (Railway/Render no persisten el filesystem), por eso en
 * producción se debe usar la implementación S3 (ver R2StorageService y
 * backend/ALMACENAMIENTO.md).
 */
class LocalStorageService implements StorageService {
  private readonly directorioBase = path.join(__dirname, "..", "..", "uploads");

  async subirArchivo(carpeta: string, archivo: ArchivoParaSubir): Promise<string> {
    const key = `${carpeta}/${nombreUnico(archivo.nombreOriginal)}`;
    const rutaAbsoluta = path.join(this.directorioBase, key);
    await fs.promises.mkdir(path.dirname(rutaAbsoluta), { recursive: true });
    await fs.promises.writeFile(rutaAbsoluta, archivo.buffer);
    return key;
  }

  obtenerUrl(key: string): string {
    return `/uploads/${key}`;
  }
}

/** Almacenamiento S3-compatible (pensado para Cloudflare R2 vía endpoint personalizado). */
class S3StorageService implements StorageService {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly urlPublicaBase: string;

  constructor() {
    const accountId = process.env.R2_ACCOUNT_ID;
    const accessKeyId = process.env.R2_ACCESS_KEY_ID;
    const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
    const bucket = process.env.R2_BUCKET_NAME;
    const urlPublicaBase = process.env.R2_PUBLIC_URL;

    if (!accountId || !accessKeyId || !secretAccessKey || !bucket || !urlPublicaBase) {
      throw new Error(
        "STORAGE_PROVIDER=s3 requiere R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, " +
          "R2_BUCKET_NAME y R2_PUBLIC_URL (ver backend/ALMACENAMIENTO.md)."
      );
    }

    this.bucket = bucket;
    this.urlPublicaBase = urlPublicaBase.replace(/\/$/, "");
    this.client = new S3Client({
      region: "auto",
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: { accessKeyId, secretAccessKey },
    });
  }

  async subirArchivo(carpeta: string, archivo: ArchivoParaSubir): Promise<string> {
    const key = `${carpeta}/${nombreUnico(archivo.nombreOriginal)}`;
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: archivo.buffer,
        ContentType: archivo.mimeType,
      })
    );
    return key;
  }

  obtenerUrl(key: string): string {
    return `${this.urlPublicaBase}/${key}`;
  }
}

function crearStorageService(): StorageService {
  const proveedor = (process.env.STORAGE_PROVIDER || "local").toLowerCase();
  if (proveedor === "s3") {
    return new S3StorageService();
  }
  return new LocalStorageService();
}

export const storageService: StorageService = crearStorageService();
