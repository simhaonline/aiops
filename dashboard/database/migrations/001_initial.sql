-- SIMHA AiOps SaaS foundation. Apply with a migration runner as a privileged
-- database owner, then run the API with a least-privilege application role.
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS telemetry;

CREATE TABLE IF NOT EXISTS app.tenants (
  id uuid PRIMARY KEY,
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$'),
  display_name text NOT NULL CHECK (length(display_name) BETWEEN 1 AND 200),
  plan text NOT NULL DEFAULT 'self_hosted' CHECK (plan IN ('self_hosted', 'starter', 'team', 'enterprise')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.memberships (
  tenant_id uuid NOT NULL REFERENCES app.tenants(id) ON DELETE CASCADE,
  subject text NOT NULL CHECK (length(subject) BETWEEN 1 AND 320),
  role text NOT NULL CHECK (role IN ('owner', 'admin', 'operator', 'viewer')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, subject)
);

CREATE TABLE IF NOT EXISTS app.projects (
  id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES app.tenants(id) ON DELETE CASCADE,
  slug text NOT NULL CHECK (slug ~ '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$'),
  display_name text NOT NULL,
  state text NOT NULL DEFAULT 'idle' CHECK (state IN ('idle', 'running', 'stopped', 'error')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, slug)
);
CREATE INDEX IF NOT EXISTS projects_tenant_updated_idx ON app.projects (tenant_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS app.knowledge_documents (
  id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES app.tenants(id) ON DELETE CASCADE,
  project_id uuid REFERENCES app.projects(id) ON DELETE CASCADE,
  source_uri text NOT NULL,
  content_hash text NOT NULL,
  mime_type text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, content_hash)
);

CREATE TABLE IF NOT EXISTS app.knowledge_chunks (
  id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES app.tenants(id) ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES app.knowledge_documents(id) ON DELETE CASCADE,
  chunk_index integer NOT NULL CHECK (chunk_index >= 0),
  content text NOT NULL,
  embedding vector(1536),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (document_id, chunk_index)
);
CREATE INDEX IF NOT EXISTS knowledge_chunks_tenant_idx ON app.knowledge_chunks (tenant_id, document_id);
CREATE INDEX IF NOT EXISTS knowledge_chunks_embedding_hnsw ON app.knowledge_chunks USING hnsw (embedding vector_cosine_ops);

CREATE TABLE IF NOT EXISTS telemetry.request_events (
  occurred_at timestamptz NOT NULL DEFAULT now(),
  tenant_id uuid NOT NULL,
  request_id uuid NOT NULL,
  provider text NOT NULL,
  model text NOT NULL,
  input_tokens integer NOT NULL DEFAULT 0 CHECK (input_tokens >= 0),
  output_tokens integer NOT NULL DEFAULT 0 CHECK (output_tokens >= 0),
  latency_ms integer NOT NULL DEFAULT 0 CHECK (latency_ms >= 0),
  estimated_cost numeric(18,8) NOT NULL DEFAULT 0 CHECK (estimated_cost >= 0),
  status text NOT NULL CHECK (status IN ('success', 'error', 'cancelled')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
SELECT create_hypertable('telemetry.request_events', 'occurred_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS request_events_tenant_time_idx ON telemetry.request_events (tenant_id, occurred_at DESC);

ALTER TABLE app.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.knowledge_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.knowledge_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry.request_events ENABLE ROW LEVEL SECURITY;

-- The API must set LOCAL app.tenant_id inside every transaction. No tenant
-- context means no rows are visible, which is safer than an implicit tenant.
CREATE POLICY tenants_isolation ON app.tenants USING (id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY memberships_isolation ON app.memberships USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY projects_isolation ON app.projects USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY documents_isolation ON app.knowledge_documents USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY chunks_isolation ON app.knowledge_chunks USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY request_events_isolation ON telemetry.request_events USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
