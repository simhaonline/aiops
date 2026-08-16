import { Module } from "@nestjs/common";
import { HealthController } from "./health.controller";
import { OverviewController } from "./overview.controller";
import { OperationsController } from "./operations.controller";
import { PlatformService } from "./platform.service";

@Module({controllers:[HealthController,OverviewController,OperationsController],providers:[PlatformService]})
export class AppModule {}
