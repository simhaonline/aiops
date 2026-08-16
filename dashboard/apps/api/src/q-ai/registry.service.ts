import { Injectable } from "@nestjs/common";
import { loadQAIConfig } from "./q-ai.config";
import { ModelState, QAIRequest } from "./q-ai.types";
import { routingScore } from "./algorithms";

@Injectable()
export class QAIRegistryService {
  eligible(request: QAIRequest): ModelState[] { const config = loadQAIConfig(); const requested = request.candidates?.length ? new Set(request.candidates) : undefined; return config.models.filter(model => model.enabled && model.availability > 0 && (!requested || requested.has(`${model.provider}:${model.modelId}`))).sort((a, b) => routingScore(b) - routingScore(a)); }
  state() { const config = loadQAIConfig(); return { version: "q-ai-registry/1", count: config.models.length, models: config.models.map(model => ({ ...model, score: routingScore(model) })) }; }
}
