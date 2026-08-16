# Q-AI architecture

```text
Request -> feature/auth gate -> registry -> routing score
        -> bounded parallel LiteLLM calls -> schema normalization
        -> correlation correction -> interference + Bayesian fusion
        -> confidence/stability measurement -> versioned decision
```

The implementation lives in `dashboard/apps/api/src/q-ai/`. `QAIController`
is an internal token-authorized boundary. `QAIOrchestratorService` owns the
pipeline; registry and provider client are injected services; pure mathematics
is isolated in `algorithms.ts` for deterministic tests.

The Go broker is deliberately not in this path. Q-AI cannot execute shell
commands, access Docker, or receive provider secrets. The LiteLLM URL defaults
to `http://127.0.0.1:4000` and can be changed only through deployment config.
The generated dashboard deployment keeps both activation flags false; enabling
production requires explicit operator acknowledgement and a reviewed registry.

## Current and future boundaries

The current implementation uses in-process concurrency and no durable queue.
Future workers may persist request/evidence/decision records in the existing
tenant-aware PostgreSQL/TimescaleDB schemas after authenticated tenant context
is implemented.
