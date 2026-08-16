import assert from "node:assert/strict";
import test from "node:test";
import { QAIController } from "./q-ai.controller";

test("Q-AI is disabled unless explicitly enabled", () => {
  const previous = process.env.Q_AI_ENABLED;
  const previousAck = process.env.Q_AI_PRODUCTION_ACK;
  delete process.env.Q_AI_ENABLED;
  delete process.env.Q_AI_PRODUCTION_ACK;
  const controller = new QAIController({ evaluate: async () => { throw new Error("not called"); } } as never, { state: () => ({}) } as never);
  assert.equal(controller.health().enabled, false);
  if (previous === undefined) delete process.env.Q_AI_ENABLED; else process.env.Q_AI_ENABLED = previous;
  if (previousAck === undefined) delete process.env.Q_AI_PRODUCTION_ACK; else process.env.Q_AI_PRODUCTION_ACK = previousAck;
});

test("production activation requires the explicit acknowledgement flag", () => {
  const previous = process.env.Q_AI_ENABLED;
  const previousAck = process.env.Q_AI_PRODUCTION_ACK;
  process.env.Q_AI_ENABLED = "true";
  delete process.env.Q_AI_PRODUCTION_ACK;
  const controller = new QAIController({ evaluate: async () => { throw new Error("not called"); } } as never, { state: () => ({}) } as never);
  assert.equal(controller.health().enabled, false);
  process.env.Q_AI_ENABLED = previous ?? "false";
  if (previousAck === undefined) delete process.env.Q_AI_PRODUCTION_ACK; else process.env.Q_AI_PRODUCTION_ACK = previousAck;
});
