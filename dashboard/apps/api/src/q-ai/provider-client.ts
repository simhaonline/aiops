import { Injectable } from "@nestjs/common";
import { ModelEvidence, ModelState } from "./q-ai.types";
import { loadQAIConfig } from "./q-ai.config";

type ChatResponse = { choices?: Array<{ message?: { content?: unknown } }>; usage?: { prompt_tokens?: number; completion_tokens?: number } };
@Injectable()
export class QAIProviderClient {
  private readonly circuits = new Map<string, { failures: number; openedUntil: number }>();
  async generate(model: ModelState, prompt: string, timeoutMs: number): Promise<ModelEvidence> {
    const started = Date.now();
    const modelName = `${model.provider}:${model.modelId}`;
    const config = loadQAIConfig();
    const circuit = this.circuits.get(modelName);
    if (circuit && circuit.openedUntil > Date.now()) return this.failure(modelName, model.provider, started, "provider circuit is open");
    let lastError = "provider request failed";
    for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
    try {
      const response = await fetch(`${process.env.Q_AI_GATEWAY_URL ?? "http://127.0.0.1:4000"}/chat/completions`, {
        method: "POST", headers: { "content-type": "application/json", ...(process.env.LITELLM_MASTER_KEY ? { authorization: `Bearer ${process.env.LITELLM_MASTER_KEY}` } : {}) },
        body: JSON.stringify({ model: model.modelId, messages: [{ role: "user", content: prompt }], temperature: 0, response_format: { type: "json_object" } }),
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (!response.ok) throw new Error(`gateway returned ${response.status}`);
      const payload = await response.json() as ChatResponse;
      const content = String(payload.choices?.[0]?.message?.content ?? "");
      const parsed = parseEvidence(content);
      this.circuits.delete(modelName);
      return { model: modelName, provider: model.provider, ...parsed, latencyMs: Date.now() - started, inputTokens: payload.usage?.prompt_tokens ?? 0, outputTokens: payload.usage?.completion_tokens ?? 0, cost: 0, status: "success" };
    } catch (error) {
      lastError = error instanceof Error ? error.message : "provider request failed";
      if (attempt < config.maxRetries) await new Promise(resolve => setTimeout(resolve, Math.min(250 * 2 ** attempt, 2_000)));
    }
    }
    const failures = (this.circuits.get(modelName)?.failures ?? 0) + 1;
    this.circuits.set(modelName, { failures, openedUntil: failures >= config.circuitBreakerFailures ? Date.now() + config.circuitBreakerCooldownMs : 0 });
    return this.failure(modelName, model.provider, started, lastError);
  }
  private failure(model: string, provider: string, started: number, error: string): ModelEvidence { return { model, provider, prediction: "INSUFFICIENT_CONFIDENCE", probabilities: { INSUFFICIENT_CONFIDENCE: 1 }, confidence: 0, latencyMs: Date.now() - started, inputTokens: 0, outputTokens: 0, cost: 0, status: "error", error }; }
}
function parseEvidence(content: string): Pick<ModelEvidence, "prediction" | "probabilities" | "confidence" | "reasoningSummary" | "evidence"> {
  try {
    const parsed = JSON.parse(content) as Record<string, unknown>;
    const probabilities = parsed.probabilities && typeof parsed.probabilities === "object" ? Object.fromEntries(Object.entries(parsed.probabilities as Record<string, unknown>).filter(([, value]) => Number.isFinite(Number(value))).map(([key, value]) => [key, Math.max(Number(value), 0)])) : {};
    const normalized = Object.keys(probabilities).length ? probabilities : { [String(parsed.prediction ?? "UNKNOWN")]: 1 };
    const prediction = String(parsed.prediction ?? Object.entries(normalized).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "UNKNOWN");
    const confidence = Math.min(Math.max(Number(parsed.confidence ?? normalized[prediction] ?? .5), 0), 1);
    return { prediction, probabilities: normalized, confidence, reasoningSummary: typeof parsed.reasoning_summary === "string" ? parsed.reasoning_summary.slice(0, 2000) : undefined, evidence: Array.isArray(parsed.evidence) ? parsed.evidence.filter(item => typeof item === "string").map(item => item.slice(0, 500)).slice(0, 20) : undefined };
  } catch { return { prediction: "UNKNOWN", probabilities: { UNKNOWN: 1 }, confidence: 0, reasoningSummary: "Provider returned non-JSON output; excluded from confident fusion." }; }
}
