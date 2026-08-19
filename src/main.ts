import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, OpenAPIObject, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

// Inlines every $ref with the schema NestJS derived from the DTO's own decorators, so paths stay self-contained without a hand-duplicated copy.
function inlineSchemaRefs(document: OpenAPIObject): OpenAPIObject {
  const schemas = document.components?.schemas ?? {};
  const resolve = (node: unknown, seen: ReadonlySet<string>): unknown => {
    if (Array.isArray(node)) {
      return node.map((item) => resolve(item, seen));
    }
    if (node && typeof node === 'object') {
      const ref = (node as { $ref?: string }).$ref;
      if (typeof ref === 'string' && ref.startsWith('#/components/schemas/')) {
        const name = ref.slice('#/components/schemas/'.length);
        if (seen.has(name) || !schemas[name]) {
          return node;
        }
        return resolve(schemas[name], new Set(seen).add(name));
      }
      return Object.fromEntries(
        Object.entries(node).map(([key, value]) => [key, resolve(value, seen)]),
      );
    }
    return node;
  };
  document.paths = resolve(document.paths, new Set()) as OpenAPIObject['paths'];
  return document;
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableShutdownHooks();
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, transform: true }),
  );

  const config = new DocumentBuilder()
    .setTitle('URL shortener')
    .setDescription('Turns a long URL into a short slug, redirects on it, and counts hits.')
    .setVersion('0.0.1')
    .build();
  const document = inlineSchemaRefs(SwaggerModule.createDocument(app, config));
  SwaggerModule.setup('api', app, document);

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
}

bootstrap();
