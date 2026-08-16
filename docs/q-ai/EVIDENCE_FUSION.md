# Evidence fusion

Q-AI does not average labels. It first reduces duplicate evidence using model
response correlation, then applies a Bayesian-inspired log update:

```text
log P(H|E) = log P(H) + Σ model_weight × log(max(P(E|H), 1e-6))
```

The posterior is stabilized with log-sum normalization. A 75/25 blend with the
classical interference posterior is used by the initial foundation and is
versioned; it is a tunable policy, not a claim of optimality. Calibration data
and benchmark outcomes must justify future policy changes.
