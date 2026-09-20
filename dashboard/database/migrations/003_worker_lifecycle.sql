-- Worker lifecycle fields and claim indexes. Additive for installations that
-- already applied 001/002.
ALTER TABLE app.background_jobs DROP CONSTRAINT IF EXISTS background_jobs_initiated_by_fkey;
ALTER TABLE app.background_jobs ALTER COLUMN initiated_by TYPE text USING initiated_by::text;
ALTER TABLE app.background_jobs ADD COLUMN IF NOT EXISTS max_attempts integer NOT NULL DEFAULT 3 CHECK (max_attempts BETWEEN 1 AND 20);
ALTER TABLE app.background_jobs ADD COLUMN IF NOT EXISTS last_heartbeat timestamptz;
ALTER TABLE app.background_jobs ADD COLUMN IF NOT EXISTS request_id text;
ALTER TABLE app.background_jobs ADD COLUMN IF NOT EXISTS error_code text;
ALTER TABLE app.background_jobs ADD COLUMN IF NOT EXISTS retryable boolean NOT NULL DEFAULT true;
ALTER TABLE app.background_jobs ADD COLUMN IF NOT EXISTS run_after timestamptz NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS jobs_claim_idx ON app.background_jobs(status, run_after, created_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS jobs_heartbeat_idx ON app.background_jobs(status, last_heartbeat) WHERE status = 'running';
