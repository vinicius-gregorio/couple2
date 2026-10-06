import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { configureApp } from './configure-app';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  configureApp(app);
  // Railway sets PORT. Bind all interfaces so the container is reachable.
  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}
void bootstrap();
