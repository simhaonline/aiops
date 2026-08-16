# Model routing

Eligible models are supplied by `Q_AI_MODELS_JSON` and filtered by enabled
state, availability, and optional request candidates. The default score is a
documented weighted sum:

```text
score = (0.20 reliability + 0.20 accuracy + 0.10 calibration
       + 0.10 latency_efficiency + 0.10 cost_efficiency
       + 0.10 task_fit + 0.10 domain_fit + 0.05 independence
       + 0.05 availability) / 1.00
```

The values are normalized to `[0,1]`, configurable in code initially, and
recorded through the registry version. The first implementation uses bounded
ranked selection rather than silently exploring paid providers. Future
exploration can add epsilon-greedy or Thompson sampling after outcome data and
provider policy are available.
