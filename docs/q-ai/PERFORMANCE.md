# Performance and cost

Each evidence record carries latency, input tokens, output tokens, and cost.
The orchestrator enforces maximum models per round, maximum rounds, per-call
timeout, and a bounded prompt size. It can early-terminate when confidence and
leave-one-out stability exceed configured thresholds.

Benchmark work remains pending because no provider test credentials or labeled
task dataset are present. Required comparisons are single-model, sequential,
parallel, adaptive, and early-termination modes across p50/p95/p99 latency,
cost, error rate, Brier score, calibration error, and decision quality.
