# Q-AI rollout and rollback

Q-AI is disabled by default. Production activation requires both
`Q_AI_ENABLED=true` and the explicit `Q_AI_PRODUCTION_ACK=true`. To keep
existing behavior unchanged, leave either flag unset or set it to `false`.
`Q_AI_SHADOW=true` is reserved for a
future comparison path and does not replace the existing Studio response.

Rollback is immediate: remove/disable either Q-AI activation flag, restart the
API container, and verify `/api/q-ai/health` reports `enabled: false`. No Q-AI
migration is required by the initial foundation, so disabling it does not
alter existing project, provider, or dashboard state.
