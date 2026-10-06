import { INestApplication, ValidationPipe } from '@nestjs/common';

/**
 * Unset or empty CORS_ORIGINS reflects the request origin (local dev and
 * any Firebase Hosting host). A comma-separated list restricts the allow-list.
 */
function corsOrigin(): boolean | string[] {
  const configured = process.env.CORS_ORIGINS?.split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
  if (!configured || configured.length === 0) {
    return true;
  }
  return configured;
}

export function configureApp(app: INestApplication) {
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.enableCors({
    origin: corsOrigin(),
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
    allowedHeaders: 'Content-Type, Accept, Authorization',
  });
}
