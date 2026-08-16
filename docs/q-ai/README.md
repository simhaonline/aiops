# Q-AI: quantum-inspired classical orchestration

Q-AI is a feature-flagged, vendor-neutral orchestration layer for SIMHA AiOps.
It uses classical probability, ensemble, Bayesian, correlation, and state
transition algorithms inspired by quantum terminology. It is not quantum
computing and provides no quantum speedup or hardware acceleration.

Current foundation:

- disabled unless `Q_AI_ENABLED=true`;
- calls the existing LiteLLM loopback gateway, never provider keys directly;
- validates and normalizes JSON evidence;
- executes eligible models concurrently with per-call timeouts;
- applies correlation-adjusted Bayesian fusion and a classical interference
  score;
- returns versioned confidence, stability, cost, latency, and evidence metadata;
- rejects requests when no configured model or authorization is available.

The service is intentionally not production-enabled until tenant authentication,
durable outcome storage, calibration data, and provider policy integration are
available.

Minimal internal configuration is supplied as JSON, for example:

```sh
export Q_AI_ENABLED=true
export Q_AI_PRODUCTION_ACK=true
export Q_AI_MODELS_JSON='[{"provider":"openrouter","modelId":"vendor/model","enabled":true,"reliability":0.8,"accuracy":0.8,"calibration":0.8,"latencyEfficiency":0.8,"costEfficiency":0.8,"taskFit":0.8,"domainFit":0.8,"independence":0.8,"availability":1}]'
```

Both flags are required. Keep them false until the model registry,
authentication, data policy, and LiteLLM route have been reviewed.

See [REPOSITORY_AUDIT.md](REPOSITORY_AUDIT.md), [ARCHITECTURE.md](ARCHITECTURE.md),
and [ROLLBACK.md](ROLLBACK.md).
