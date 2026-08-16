# Q-AI testing

Current deterministic tests cover probability normalization, routing bounds,
correlation weight reduction, constructive fusion, and stability. The full
dashboard test command also compiles the API, runs NestJS tests, Go tests, and
Python telemetry tests.

Required next tests are mocked LiteLLM integration, timeout/429/5xx isolation,
malformed JSON, all-provider failure, authorization, tenant context, migration
validation, load tests, ablation tests, and labeled walk-forward benchmarks.
