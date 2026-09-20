import { Module } from "@nestjs/common";
import { HealthController } from "./health.controller";
import { OverviewController } from "./overview.controller";
import { OperationsController } from "./operations.controller";
import { PlatformService } from "./platform.service";
import { WorkspaceController } from "./workspace.controller";
import { DatabaseService } from "./database.service";
import { QAIModule } from "./q-ai/q-ai.module";
import { WorkspaceDataController } from "./workspace-data.controller";
import { WorkspaceAuthGuard } from "./auth.service";
import { JobService } from "./job.service";
import { JobWorker } from "./job-worker";
import { StorageService } from "./storage.service";
import { DevelopmentMediaProvider, EmbeddingProviderService, GitRepositoryProvider } from "./providers";

@Module({imports:[QAIModule],controllers:[HealthController,OverviewController,OperationsController,WorkspaceController,WorkspaceDataController],providers:[PlatformService,DatabaseService,WorkspaceAuthGuard,JobService,JobWorker,StorageService,GitRepositoryProvider,EmbeddingProviderService,DevelopmentMediaProvider],exports:[DatabaseService,JobService,JobWorker]})
export class AppModule {}
