# Quantum-inspired classical model

The term “quantum-inspired” describes a classical mathematical metaphor only.
No qubits, quantum hardware, quantum SDK, quantum supremacy, or quantum
advantage are present.

For candidate probability `p`, the amplitude magnitude is:

```text
amplitude = sqrt(clamp(p, 0, 1))
```

Matching predictions receive a positive signed contribution; contradictory
predictions receive a negative contribution. Squared summed amplitudes are
normalized into an interference posterior. This models constructive and
destructive reinforcement but is not physical quantum interference.

Numerical safeguards clamp non-finite values, use a positive probability floor
for log fusion, and normalize every distribution. Tests cover agreement,
contradiction, and empty fields.
