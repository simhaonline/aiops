# Q-AI observability

The decision contract exposes model count, rounds, latency, cost, token totals,
confidence, stability, agreement, disagreement, early termination, algorithm
versions, and per-model error metadata. This is the initial audit surface.

The repository has no existing Prometheus/OpenTelemetry SDK. Future metrics
should extend the existing telemetry service rather than add a second stack:
`qai_requests_total`, `qai_provider_failures_total`, `qai_model_calls_total`,
`qai_early_termination_total`, `qai_cost_total`, `qai_latency_ms`,
`qai_confidence`, `qai_stability`, and `qai_calibration_error`.
