import { Body, Controller, Get, Headers, HttpException, HttpStatus, Post } from "@nestjs/common";
import { loadQAIConfig } from "./q-ai.config";
import { QAIOrchestratorService } from "./orchestrator.service";
import { QAIRegistryService } from "./registry.service";
import { QAIRequest } from "./q-ai.types";

@Controller("q-ai")
export class QAIController {
  constructor(private readonly orchestrator: QAIOrchestratorService, private readonly registry: QAIRegistryService) {}
  @Get("health") health() { const config = loadQAIConfig(); return { enabled: config.enabled, productionAck: config.productionAck, ready: config.enabled && config.models.length > 0, shadow: config.shadow, configuredModels: config.models.length, versions: { router: "q-ai-router/1", fusion: "q-ai-fusion/1", calibration: "q-ai-calibration/1", policy: "q-ai-policy/1", registry: "q-ai-registry/1" } }; }
  @Get("models") models(@Headers("x-aiops-dashboard-token") token?: string) { this.authorize(token); return this.registry.state(); }
  @Post("evaluate") async evaluate(@Headers("x-aiops-dashboard-token") token: string | undefined, @Body() body: QAIRequest) { this.authorize(token); const config = loadQAIConfig(); if (!config.enabled) throw new HttpException("Q-AI is disabled", HttpStatus.NOT_FOUND); return this.orchestrator.evaluate({ prompt: String(body?.prompt ?? ""), task: body?.task, domain: body?.domain, candidates: Array.isArray(body?.candidates) ? body.candidates.slice(0, 16).map(String) : undefined, maxModels: Number(body?.maxModels), maxRounds: Number(body?.maxRounds) }); }
  private authorize(token?: string) { const expected = process.env.AIOPS_DASHBOARD_TOKEN; if (!expected || !token || token.length !== expected.length || !timingSafeEqual(token, expected)) throw new HttpException("authorization failed", HttpStatus.UNAUTHORIZED); }
}
function timingSafeEqual(a: string, b: string) { let result = 0; for (let index = 0; index < a.length; index++) result |= a.charCodeAt(index) ^ b.charCodeAt(index); return result === 0; }
