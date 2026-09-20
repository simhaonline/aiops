import "reflect-metadata";
import { ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { FastifyAdapter, NestFastifyApplication } from "@nestjs/platform-fastify";
import { AppModule } from "./app.module";
import { HttpExceptionResponseFilter } from "./http-exception.filter";

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter({logger:true}), {bodyParser:true});
  app.setGlobalPrefix("api");
  app.useGlobalPipes(new ValidationPipe({whitelist:true,forbidNonWhitelisted:true,transform:true}));
  app.useGlobalFilters(new HttpExceptionResponseFilter());
  await app.listen({host:"127.0.0.1",port:Number(process.env.AIOPS_API_PORT ?? 11081)});
}
void bootstrap();
