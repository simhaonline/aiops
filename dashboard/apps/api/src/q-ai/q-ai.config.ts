import { ModelState } from "./q-ai.types";

export const QAI_VERSIONS = { router: "q-ai-router/1", fusion: "q-ai-fusion/1", calibration: "q-ai-calibration/1", policy: "q-ai-policy/1", registry: "q-ai-registry/1" } as const;
export interface QAIConfig {
  enabled: boolean; shadow: boolean; maxParallelModels: number; maxRounds: number; timeoutMs: number; earlyStopThreshold: number; minimumStability: number; minimumInformationGain: number; maxCost: number; explorationRate: number; models: ModelState[];
}
const bounded = (value: unknown, fallback: number, min: number, max: number) => { const number = Number(value); return Number.isFinite(number) ? Math.min(Math.max(number, min), max) : fallback; };

export function loadQAIConfig(): QAIConfig {
  let models: ModelState[] = [];
  try { const parsed = JSON.parse(process.env.Q_AI_MODELS_JSON ?? "[]"); if (Array.isArray(parsed)) models = parsed.filter(isModelState); } catch { models = []; }
  return {
    enabled: process.env.Q_AI_ENABLED === "true",
    shadow: process.env.Q_AI_SHADOW === "true",
    maxParallelModels: Math.floor(bounded(process.env.Q_AI_MAX_PARALLEL_MODELS, 3, 1, 8)),
    maxRounds: Math.floor(bounded(process.env.Q_AI_MAX_ROUNDS, 2, 1, 3)),
    timeoutMs: Math.floor(bounded(process.env.Q_AI_TIMEOUT_MS, 10_000, 500, 60_000)),
    earlyStopThreshold: bounded(process.env.Q_AI_EARLY_STOP_THRESHOLD, 0.9, 0.5, 0.999),
    minimumStability: bounded(process.env.Q_AI_MIN_STABILITY, 0.85, 0, 1),
    minimumInformationGain: bounded(process.env.Q_AI_MIN_INFORMATION_GAIN, 0.05, 0, 1),
    maxCost: bounded(process.env.Q_AI_MAX_COST, 0.1, 0, 100),
    explorationRate: bounded(process.env.Q_AI_EXPLORATION_RATE, 0.05, 0, 1),
    models,
  };
}
function isModelState(value: unknown): value is ModelState {
  if (!value || typeof value !== "object") return false;
  const item = value as Partial<ModelState>;
  return typeof item.provider === "string" && typeof item.modelId === "string" && item.enabled !== false;
}
