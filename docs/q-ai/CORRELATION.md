# Correlation and independence

The initial correlation matrix combines structured prediction agreement,
confidence proximity, and token overlap in concise reasoning/evidence fields:

```text
correlation = .55 prediction_agreement
            + .25 evidence_token_overlap
            + .20 confidence_similarity
```

Effective weight is reduced by the mean correlation with other models. This is
a deterministic proxy until historical co-error and embedding features are
available. It must not be interpreted as a causal independence proof.
