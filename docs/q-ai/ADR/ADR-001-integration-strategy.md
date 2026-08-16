# ADR-001: Add Q-AI above LiteLLM

**Decision:** integrate Q-AI as an optional NestJS module that calls the
existing LiteLLM loopback gateway.

**Rationale:** provider keys, model discovery, and free-provider policy already
belong to `litellm-manager`; duplicating SDKs would create conflicting routing
and secret boundaries. The module is disabled by default and does not touch the
privileged broker.
