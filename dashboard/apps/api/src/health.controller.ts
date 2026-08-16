import { Controller, Get } from "@nestjs/common";
import { DatabaseService } from "./database.service";
@Controller("health") export class HealthController {
  constructor(private readonly database: DatabaseService) {}
  @Get() async health(){return {status:"ok",service:"aiops-api",version:"1.0.0",database:await this.database.health()};}
}
