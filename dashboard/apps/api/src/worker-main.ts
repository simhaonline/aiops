import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { JobWorker } from "./job-worker";

async function main(){const app=await NestFactory.createApplicationContext(AppModule,{logger:["error","warn","log"]});const worker=app.get(JobWorker);const stop=()=>{worker.stop();void app.close();};process.once("SIGTERM",stop);process.once("SIGINT",stop);try{await worker.run(process.env.AIOPS_WORKER_ONCE === "true");}finally{await app.close();}}
void main();
