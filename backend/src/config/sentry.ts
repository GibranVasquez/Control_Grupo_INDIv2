import * as Sentry from "@sentry/node";

/// Sin SENTRY_DSN el SDK queda deshabilitado (no manda nada, no hay overhead
/// real) — así que es seguro llamar a esto siempre, incluso en desarrollo
/// local o antes de que exista una cuenta de Sentry. Cuando se defina la
/// variable de entorno, queda activo sin tocar código.
export function inicializarSentry(): void {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV ?? "development",
  });
}

/// Solo se reportan errores inesperados (500 o que no sean AppError): un
/// AppError (400/403/404/etc.) es un rechazo de negocio esperado, no una
/// falla que alguien deba investigar en Sentry.
export function reportarErrorInesperado(err: unknown): void {
  Sentry.captureException(err);
}
