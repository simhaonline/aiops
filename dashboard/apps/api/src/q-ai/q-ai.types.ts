export type Candidate = string;
export type QAIStatus = "ok" | "insufficient_confidence" | "unavailable";

export interface ModelState {
  provider: string;
  modelId: string;
  displayName?: string;
  capabilities?: string[];
  enabled: boolean;
  reliability: number;
  accuracy: number;
  calibration: number;
  latencyEfficiency: number;
  costEfficiency: number;
  taskFit: number;
  domainFit: number;
  independence: number;
  availability: number;
}

export interface QAIRequest {
  prompt: string;
  task?: string;
  domain?: string;
  candidates?: Candidate[];
  maxModels?: number;
  maxRounds?: number;
}

export interface ModelEvidence {
  model: string;
  provider: string;
  prediction: string;
  probabilities: Record<string, number>;
  confidence: number;
  reasoningSummary?: string;
  evidence?: string[];
  latencyMs: number;
  inputTokens: number;
  outputTokens: number;
  cost: number;
  status: "success" | "error";
  error?: string;
}

export interface CorrelationResult { matrix: Record<string, Record<string, number>>; effectiveWeights: Record<string, number>; }
export interface Decision {
  status: QAIStatus;
  decision?: string;
  probabilities: Record<string, number>;
  confidence: number;
  stability: number;
  agreement: number;
  independentConfirmation: number;
  modelCount: number;
  earlyTermination: boolean;
  rounds: number;
  totalLatencyMs: number;
  totalCost: number;
  inputTokens: number;
  outputTokens: number;
  disagreement: number;
  informationGain?: number;
  metadata: { routerVersion: string; fusionVersion: string; calibrationVersion: string; policyVersion: string; modelRegistryVersion: string };
  evidence: ModelEvidence[];
  correlation: CorrelationResult;
}
