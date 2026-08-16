import assert from "node:assert/strict";
import test from "node:test";
import { QAIController } from "./q-ai.controller";

test("Q-AI is disabled unless explicitly enabled", () => {
  const previous = process.env.Q_AI_ENABLED;
  delete process.env.Q_AI_ENABLED;
  const controller = new QAIController({ evaluate: async () => { throw new Error("not called"); } } as never, { state: () => ({}) } as never);
  assert.equal(controller.health().enabled, false);
  if (previous === undefined) delete process.env.Q_AI_ENABLED; else process.env.Q_AI_ENABLED = previous;
});
