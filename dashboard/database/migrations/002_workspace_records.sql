-- Core workspace records. This migration is additive and keeps the original
-- app.tenants/memberships tables compatible with existing installations.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS app.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject text NOT NULL UNIQUE,
  display_name text NOT NULL,
  email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS app.workspaces (
  id uuid PRIMARY KEY REFERENCES app.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_by uuid REFERENCES app.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz
);
CREATE TABLE IF NOT EXISTS app.workspace_memberships (
  workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'viewer' CHECK (role IN ('owner','admin','operator','viewer')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, user_id)
);
-- Existing tenants become workspaces so upgrading installations can use the
-- new APIs without a destructive re-onboarding step.
INSERT INTO app.workspaces (id, name)
SELECT id, display_name FROM app.tenants
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS app.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE,
  project_id uuid REFERENCES app.projects(id) ON DELETE SET NULL, created_by uuid REFERENCES app.users(id),
  title text NOT NULL DEFAULT 'New conversation', modality text NOT NULL DEFAULT 'text', metadata jsonb NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS app.conversation_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), conversation_id uuid NOT NULL REFERENCES app.conversations(id) ON DELETE CASCADE,
  workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, role text NOT NULL CHECK (role IN ('user','assistant','system','tool')),
  content text NOT NULL, status text NOT NULL DEFAULT 'complete' CHECK (status IN ('pending','streaming','complete','failed','cancelled')),
  metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.codebases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE,
  project_id uuid REFERENCES app.projects(id) ON DELETE SET NULL, created_by uuid REFERENCES app.users(id), name text NOT NULL,
  provider text NOT NULL DEFAULT 'generic', repository_url text NOT NULL, default_branch text NOT NULL DEFAULT 'main',
  status text NOT NULL DEFAULT 'connected' CHECK (status IN ('pending','indexing','ready','failed','disconnected')),
  error_message text, metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE IF NOT EXISTS app.codebase_scans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), codebase_id uuid NOT NULL REFERENCES app.codebases(id) ON DELETE CASCADE,
  workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','succeeded','failed','cancelled')),
  progress integer NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100), error_message text, started_at timestamptz, completed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.knowledge_collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, name text NOT NULL,
  description text NOT NULL DEFAULT '', created_by uuid REFERENCES app.users(id), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE IF NOT EXISTS app.knowledge_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, collection_id uuid REFERENCES app.knowledge_collections(id) ON DELETE SET NULL,
  name text NOT NULL, source_type text NOT NULL CHECK (source_type IN ('file','website','integration')), source_uri text, mime_type text, size_bytes bigint,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','indexing','ready','failed','deleted')), error_message text, metadata jsonb NOT NULL DEFAULT '{}', created_by uuid REFERENCES app.users(id), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.media_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, name text NOT NULL,
  storage_key text NOT NULL, mime_type text NOT NULL, size_bytes bigint NOT NULL DEFAULT 0, status text NOT NULL DEFAULT 'ready' CHECK (status IN ('pending','processing','ready','failed','deleted')),
  metadata jsonb NOT NULL DEFAULT '{}', created_by uuid REFERENCES app.users(id), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS app.media_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, asset_id uuid REFERENCES app.media_assets(id) ON DELETE SET NULL,
  kind text NOT NULL, status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','succeeded','failed','cancelled')), progress integer NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
  error_message text, idempotency_key text, created_by uuid REFERENCES app.users(id), started_at timestamptz, completed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (workspace_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS app.workflows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, name text NOT NULL,
  description text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','paused','archived')), current_version integer NOT NULL DEFAULT 1,
  created_by uuid REFERENCES app.users(id), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), archived_at timestamptz
);
CREATE TABLE IF NOT EXISTS app.workflow_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workflow_id uuid NOT NULL REFERENCES app.workflows(id) ON DELETE CASCADE, workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE,
  version integer NOT NULL, definition jsonb NOT NULL, created_by uuid REFERENCES app.users(id), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (workflow_id, version)
);
CREATE TABLE IF NOT EXISTS app.workflow_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workflow_id uuid NOT NULL REFERENCES app.workflows(id) ON DELETE CASCADE, workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE,
  version integer NOT NULL, status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','succeeded','failed','cancelled','timed_out')), idempotency_key text, error_message text,
  created_by uuid REFERENCES app.users(id), started_at timestamptz, completed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (workflow_id, idempotency_key)
);
CREATE TABLE IF NOT EXISTS app.workflow_run_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), run_id uuid NOT NULL REFERENCES app.workflow_runs(id) ON DELETE CASCADE, workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE,
  step_key text NOT NULL, status text NOT NULL, message text NOT NULL DEFAULT '', metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.registry_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, name text NOT NULL, item_type text NOT NULL,
  status text NOT NULL DEFAULT 'discovered' CHECK (status IN ('discovered','quarantined','reviewed','approved','published','rejected','deprecated')), description text NOT NULL DEFAULT '', created_by uuid REFERENCES app.users(id), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS app.registry_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), item_id uuid NOT NULL REFERENCES app.registry_items(id) ON DELETE CASCADE, workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE,
  version text NOT NULL, manifest jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (item_id, version)
);
CREATE TABLE IF NOT EXISTS app.approval_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, resource_type text NOT NULL, resource_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')), requested_by uuid REFERENCES app.users(id), reviewed_by uuid REFERENCES app.users(id), reason text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now(), reviewed_at timestamptz
);

CREATE TABLE IF NOT EXISTS app.background_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, kind text NOT NULL, resource_type text, resource_id uuid,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','running','succeeded','failed','cancelled')), progress integer NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100), attempts integer NOT NULL DEFAULT 0, error_message text,
  initiated_by uuid REFERENCES app.users(id), idempotency_key text, started_at timestamptz, completed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (workspace_id, kind, idempotency_key)
);
ALTER TABLE app.background_jobs ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
CREATE TABLE IF NOT EXISTS app.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, user_id uuid REFERENCES app.users(id), kind text NOT NULL, title text NOT NULL, body text NOT NULL DEFAULT '', read_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS app.audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, actor_subject text NOT NULL, action text NOT NULL, resource_type text, resource_id uuid, result text NOT NULL, request_id text, metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS app.integration_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), workspace_id uuid NOT NULL REFERENCES app.workspaces(id) ON DELETE CASCADE, provider text NOT NULL, config jsonb NOT NULL DEFAULT '{}', secret_ref text,
  created_by uuid REFERENCES app.users(id), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (workspace_id, provider)
);

CREATE INDEX IF NOT EXISTS conversations_workspace_updated_idx ON app.conversations(workspace_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS messages_conversation_created_idx ON app.conversation_messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS codebases_workspace_updated_idx ON app.codebases(workspace_id, updated_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS knowledge_sources_workspace_status_idx ON app.knowledge_sources(workspace_id, status, updated_at DESC);
CREATE INDEX IF NOT EXISTS media_assets_workspace_created_idx ON app.media_assets(workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS workflows_workspace_updated_idx ON app.workflows(workspace_id, updated_at DESC) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS jobs_workspace_created_idx ON app.background_jobs(workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS audits_workspace_created_idx ON app.audit_events(workspace_id, created_at DESC);

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['workspace_memberships','conversations','conversation_messages','codebases','codebase_scans','knowledge_collections','knowledge_sources','media_assets','media_jobs','workflows','workflow_versions','workflow_runs','workflow_run_logs','registry_items','registry_versions','approval_requests','background_jobs','notifications','audit_events','integration_configs'] LOOP
    EXECUTE format('ALTER TABLE app.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_workspace_isolation ON app.%I', t);
    EXECUTE format('CREATE POLICY tenant_workspace_isolation ON app.%I USING (workspace_id = current_setting(''app.tenant_id'', true)::uuid)', t);
  END LOOP;
  ALTER TABLE app.users ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS tenant_user_isolation ON app.users;
  CREATE POLICY tenant_user_isolation ON app.users USING (id IN (SELECT user_id FROM app.workspace_memberships WHERE workspace_id = current_setting('app.tenant_id', true)::uuid));
  ALTER TABLE app.workspaces ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS tenant_workspace_isolation ON app.workspaces;
  CREATE POLICY tenant_workspace_isolation ON app.workspaces USING (id = current_setting('app.tenant_id', true)::uuid);
END $$;
