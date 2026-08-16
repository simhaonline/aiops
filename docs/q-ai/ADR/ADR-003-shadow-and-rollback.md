# ADR-003: Feature flag before activation

**Decision:** `Q_AI_ENABLED` defaults false; activation is an explicit
configuration change and rollback is an environment change plus API restart.

**Rationale:** the repository has no tenant auth, outcome store, benchmark set,
or production model-call endpoint in the API. Existing behavior must remain
unchanged while those dependencies are delivered.
