import { Injectable } from "@nestjs/common";
import { bayesianFusion, clamp, correlation, entropy, initialProbabilityField, interference, stability } from "./algorithms";
import { loadQAIConfig, QAI_VERSIONS } from "./q-ai.config";
import { QAIProviderClient } from "./provider-client";
import { QAIRegistryService } from "./registry.service";
import { Decision, ModelEvidence, QAIRequest } from "./q-ai.types";

@Injectable()
export class QAIOrchestratorService {
  constructor(private readonly registry: QAIRegistryService, private readonly client: QAIProviderClient) {}
  async evaluate(request: QAIRequest): Promise<Decision> {
    const config = loadQAIConfig();
    if (!config.enabled) return this.unavailable("Q-AI is disabled");
    if (!request.prompt?.trim() || request.prompt.length > 100_000) return this.unavailable("prompt is empty or too large");
    const eligible = this.registry.eligible(request); if (!eligible.length) return this.unavailable("no eligible models configured");
    const requestedModels = Number.isFinite(request.maxModels) && Number(request.maxModels) > 0 ? Math.floor(Number(request.maxModels)) : config.maxParallelModels;
    const requestedRounds = Number.isFinite(request.maxRounds) && Number(request.maxRounds) > 0 ? Math.floor(Number(request.maxRounds)) : config.maxRounds;
    const perRound = Math.min(requestedModels, config.maxParallelModels);
    const roundsLimit = Math.min(requestedRounds, config.maxRounds);
    const selected = eligible.slice(0, perRound * roundsLimit);
    const prior = initialProbabilityField(selected);
    const allEvidence: ModelEvidence[] = [];
    const started = Date.now(); const globalDeadline = started + config.timeoutMs * roundsLimit; let rounds = 0; let measured: Decision | undefined;
    while (rounds < roundsLimit) {
      rounds++;
      const remainingMs = Math.max(500, globalDeadline - Date.now());
      const batch = await Promise.all(selected.slice(allEvidence.length, allEvidence.length + perRound).map(model => this.client.generate(model, request.prompt, Math.min(config.timeoutMs, remainingMs))));
      allEvidence.push(...batch);
      const successful = allEvidence.filter(item => item.status === "success" && item.confidence > 0);
      if (!successful.length) break;
      const correlations = correlation(successful);
      const posterior = bayesianFusion(successful, correlations.effectiveWeights, prior);
      const interferencePosterior = interference(successful, correlations.effectiveWeights);
      const probabilities = Object.fromEntries(Object.keys(posterior).map(key => [key, .75 * posterior[key] + .25 * (interferencePosterior[key] ?? 0)]));
      const normalized = Object.fromEntries(Object.entries(probabilities).map(([key, value]) => [key, value]));
      const winner = Object.entries(normalized).sort((a, b) => b[1] - a[1])[0];
      const confidence = clamp(winner?.[1] ?? 0); const agreement = successful.length ? successful.filter(item => item.prediction === winner?.[0]).length / successful.length : 0; const disagreement = 1 - agreement; const state = stability(successful, normalized); const independent = clamp(successful.filter(item => item.prediction === winner?.[0]).reduce((sum, item) => sum + (1 - (correlations.matrix[item.model] ? Object.values(correlations.matrix[item.model]).filter(value => value < 1).reduce((a, b) => a + b, 0) / Math.max(Object.values(correlations.matrix[item.model]).filter(value => value < 1).length, 1) : 0)) * item.confidence, 0) / Math.max(successful.length, 1));
      measured = { status: confidence >= config.earlyStopThreshold && state >= config.minimumStability ? "ok" : "insufficient_confidence", decision: winner?.[0], probabilities: normalized, confidence, stability: state, agreement, independentConfirmation: independent, modelCount: successful.length, earlyTermination: confidence >= config.earlyStopThreshold && state >= config.minimumStability, rounds, totalLatencyMs: Date.now() - started, totalCost: allEvidence.reduce((sum, item) => sum + item.cost, 0), inputTokens: allEvidence.reduce((sum, item) => sum + item.inputTokens, 0), outputTokens: allEvidence.reduce((sum, item) => sum + item.outputTokens, 0), disagreement, informationGain: entropy(prior) - entropy(normalized), metadata: { routerVersion: QAI_VERSIONS.router, fusionVersion: QAI_VERSIONS.fusion, calibrationVersion: QAI_VERSIONS.calibration, policyVersion: QAI_VERSIONS.policy, modelRegistryVersion: QAI_VERSIONS.registry }, evidence: allEvidence, correlation: correlations };
      if (measured.earlyTermination || rounds >= roundsLimit || measured.totalCost >= config.maxCost || Date.now() >= globalDeadline) break;
    }
    return measured ?? this.unavailable("all eligible providers failed");
  }
  private unavailable(reason: string): Decision { return { status: "unavailable", probabilities: {}, confidence: 0, stability: 0, agreement: 0, independentConfirmation: 0, modelCount: 0, earlyTermination: false, rounds: 0, totalLatencyMs: 0, totalCost: 0, inputTokens: 0, outputTokens: 0, disagreement: 1, metadata: { routerVersion: QAI_VERSIONS.router, fusionVersion: QAI_VERSIONS.fusion, calibrationVersion: QAI_VERSIONS.calibration, policyVersion: QAI_VERSIONS.policy, modelRegistryVersion: QAI_VERSIONS.registry }, evidence: [], correlation: { matrix: {}, effectiveWeights: {} }, informationGain: 0 };
  }
}
