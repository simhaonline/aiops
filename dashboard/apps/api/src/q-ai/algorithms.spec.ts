import assert from "node:assert/strict";
import test from "node:test";
import { bayesianFusion, correlation, initialProbabilityField, interference, normalize, routingScore, stability } from "./algorithms";
import { ModelEvidence, ModelState } from "./q-ai.types";

const model = (provider: string, modelId: string, score = .8): ModelState => ({ provider, modelId, enabled: true, reliability: score, accuracy: score, calibration: score, latencyEfficiency: score, costEfficiency: score, taskFit: score, domainFit: score, independence: .8, availability: 1 });
const evidence = (modelName: string, prediction: string, confidence: number, probabilities: Record<string, number>): ModelEvidence => ({ model: modelName, provider: modelName.split(":")[0], prediction, confidence, probabilities, latencyMs: 1, inputTokens: 2, outputTokens: 3, cost: .01, status: "success" });

test("normalization produces a finite probability field", () => { const result = normalize({ BUY: 2, SELL: 1 }); assert.equal(result.BUY + result.SELL, 1); assert.equal(normalize({})["undefined"], undefined); });
test("routing score is bounded and initial field sums to one", () => { assert.ok(routingScore(model("a", "m")) >= 0 && routingScore(model("a", "m")) <= 1); const field = initialProbabilityField([model("a", "m"), model("b", "m")]); assert.ok(Math.abs(Object.values(field).reduce((a, b) => a + b, 0) - 1) < 1e-9); });
test("correlation reduces weight for duplicate evidence", () => { const result = correlation([evidence("a:m", "BUY", .9, { BUY: .9, SELL: .1 }), evidence("b:m", "BUY", .9, { BUY: .9, SELL: .1 }), evidence("c:m", "SELL", .8, { BUY: .2, SELL: .8 })]); assert.ok(result.effectiveWeights["a:m"] < .9); assert.equal(result.matrix["a:m"]["a:m"], 1); });
test("interference and Bayesian fusion reinforce agreement", () => { const items = [evidence("a:m", "BUY", .9, { BUY: .9, SELL: .1 }), evidence("b:m", "BUY", .8, { BUY: .8, SELL: .2 })]; const weights = { "a:m": 1, "b:m": 1 }; assert.ok(interference(items, weights).BUY > interference(items, weights).SELL); assert.ok(bayesianFusion(items, weights).BUY > .8); });
test("stability falls when one model is the only dissenting signal", () => { const items = [evidence("a:m", "BUY", .9, { BUY: .9, SELL: .1 }), evidence("b:m", "BUY", .8, { BUY: .8, SELL: .2 }), evidence("c:m", "SELL", .8, { BUY: .2, SELL: .8 })]; const posterior = bayesianFusion(items, { "a:m": 1, "b:m": 1, "c:m": 1 }); assert.ok(stability(items, posterior) >= 0.5); });
