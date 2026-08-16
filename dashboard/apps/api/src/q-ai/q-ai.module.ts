import { Module } from "@nestjs/common";
import { QAIController } from "./q-ai.controller";
import { QAIOrchestratorService } from "./orchestrator.service";
import { QAIProviderClient } from "./provider-client";
import { QAIRegistryService } from "./registry.service";

@Module({ controllers: [QAIController], providers: [QAIOrchestratorService, QAIProviderClient, QAIRegistryService], exports: [QAIOrchestratorService, QAIRegistryService] })
export class QAIModule {}
