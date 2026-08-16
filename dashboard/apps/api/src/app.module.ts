import { Module } from "@nestjs/common";
import { HealthController } from "./health.controller";
import { OverviewController } from "./overview.controller";
import { OperationsController } from "./operations.controller";
import { PlatformService } from "./platform.service";
import { WorkspaceController } from "./workspace.controller";

@Module({controllers:[HealthController,OverviewController,OperationsController,WorkspaceController],providers:[PlatformService]})
export class AppModule {}
