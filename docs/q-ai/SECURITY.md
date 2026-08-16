# Q-AI security

- `Q_AI_ENABLED` defaults to false.
- Evaluate/models endpoints require the existing dashboard token and must stay
  behind the loopback/authenticated edge.
- LiteLLM credentials remain server-side; Q-AI only uses its loopback gateway.
- Provider output is untrusted JSON and is truncated/validated before fusion.
- No hidden chain-of-thought is stored; only concise summaries and structured
  evidence are retained in the response.
- Candidate IDs are restricted to configured registry models.
- Prompt size, model count, rounds, and timeout are bounded.
- Q-AI cannot access the root broker, Docker, filesystem project secrets, or
  payment systems.

Before multi-tenant production activation, add authenticated tenant context,
provider data-classification policy, rate limits, redaction, and durable audit
storage with RLS.
