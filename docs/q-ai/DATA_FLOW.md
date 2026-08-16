# Q-AI data flow

1. An authorized internal client submits a bounded prompt and optional task,
   domain, and candidate model IDs.
2. The feature gate and registry reject disabled, unavailable, or unconfigured
   models.
3. Routing scores select a bounded per-round set.
4. LiteLLM-compatible calls run concurrently and return only structured
   prediction, probabilities, evidence summaries, usage, cost, and latency.
5. Failed calls are isolated as evidence errors; they do not crash the request.
6. Correlation reduces duplicate-vote weight; interference is a classical
   signed-amplitude score; Bayesian fusion produces a normalized posterior.
7. Measurement computes confidence, agreement, disagreement, leave-one-out
   stability, and an early-termination decision.
8. The response includes algorithm versions and no secrets or hidden
   chain-of-thought.

There is currently no automatic outcome learner: without delayed ground truth,
Q-AI reports uncertainty instead of inventing accuracy.
