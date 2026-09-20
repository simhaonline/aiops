import { Injectable, Logger } from "@nestjs/common";
import type { PoolClient } from "pg";
import { DatabaseService } from "./database.service";

export type JobStatus = "pending"|"running"|"succeeded"|"failed"|"cancelled";
export type JobRecord = { id:string; workspace_id:string; initiated_by:string|null; kind:string; resource_type:string|null; resource_id:string|null; status:JobStatus; progress:number; attempts:number; max_attempts:number; error_message:string|null; error_code:string|null; retryable:boolean; request_id:string|null };

@Injectable()
export class JobService {
  private readonly logger = new Logger(JobService.name);
  constructor(private readonly database: DatabaseService) {}

  async enqueue(input:{workspaceId:string; initiatedBy?:string; kind:string; resourceType?:string; resourceId?:string; idempotencyKey?:string; requestId?:string; maxAttempts?:number}) {
    if (!this.database.configured()) throw new Error("AIOPS_DATABASE_URL is required for background jobs.");
    return this.database.withTenant(input.workspaceId, async client => {
      const result = await client.query<JobRecord>(`INSERT INTO app.background_jobs(workspace_id,initiated_by,kind,resource_type,resource_id,idempotency_key,request_id,max_attempts) VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT (workspace_id,kind,idempotency_key) DO UPDATE SET kind=EXCLUDED.kind RETURNING *`, [input.workspaceId,input.initiatedBy??null,input.kind,input.resourceType??null,input.resourceId??null,input.idempotencyKey??null,input.requestId??null,Math.min(Math.max(input.maxAttempts??3,1),20)]);
      return result.rows[0];
    });
  }

  async claim(tenantId:string, workerId:string) {
    if (!this.database.configured()) return null;
    return this.database.withTenant(tenantId, async client => {
      const result = await client.query<JobRecord>(`WITH next_job AS (SELECT id FROM app.background_jobs WHERE workspace_id=$1 AND status='pending' AND run_after <= now() ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT 1) UPDATE app.background_jobs AS job SET status='running', attempts=attempts+1, started_at=COALESCE(started_at,now()), last_heartbeat=now(), request_id=COALESCE(request_id,$2), updated_at=now() FROM next_job WHERE job.id=next_job.id RETURNING job.*`, [tenantId, workerId]);
      return result.rows[0] ?? null;
    });
  }

  async heartbeat(tenantId:string, id:string, progress:number) { return this.database.withTenant(tenantId, client => client.query("UPDATE app.background_jobs SET progress=$1,last_heartbeat=now(),updated_at=now() WHERE id=$2 AND workspace_id=$3 AND status='running'", [Math.min(Math.max(progress,0),100),id,tenantId])); }
  async complete(tenantId:string,id:string) { return this.database.withTenant(tenantId, client => client.query("UPDATE app.background_jobs SET status='succeeded',progress=100,completed_at=now(),last_heartbeat=now(),updated_at=now() WHERE id=$1 AND workspace_id=$2 AND status='running'", [id,tenantId])); }
  async fail(tenantId:string, id:string, errorCode:string, safeMessage:string, retryable:boolean) { return this.database.withTenant(tenantId, async client => { const result=await client.query<{attempts:number;max_attempts:number}>("SELECT attempts,max_attempts FROM app.background_jobs WHERE id=$1 AND workspace_id=$2 FOR UPDATE",[id,tenantId]); const row=result.rows[0]; const canRetry=retryable && row && row.attempts < row.max_attempts; const delay=Math.min(60_000 * 2 ** Math.max((row?.attempts??1)-1,0), 3_600_000); await client.query("UPDATE app.background_jobs SET status=$1,error_code=$2,error_message=$3,retryable=$4,run_after=$5,completed_at=$6,updated_at=now() WHERE id=$7 AND workspace_id=$8",[canRetry?"pending":"failed",errorCode,safeMessage,retryable,canRetry?new Date(Date.now()+delay):new Date(),canRetry?null:new Date(),id,tenantId]); this.logger.warn(`job ${id} ${canRetry?"scheduled for retry":"failed permanently"}: ${errorCode}`); return {retryScheduled:canRetry}; }); }
  async cancel(tenantId:string,id:string) { return this.database.withTenant(tenantId, client => client.query("UPDATE app.background_jobs SET status='cancelled',completed_at=now(),updated_at=now() WHERE id=$1 AND workspace_id=$2 AND status IN ('pending','running')",[id,tenantId])); }
  async stale(tenantId:string, timeoutMs=300_000) { return this.database.withTenant(tenantId, client => client.query("UPDATE app.background_jobs SET status=CASE WHEN attempts < max_attempts AND retryable THEN 'pending' ELSE 'failed' END,error_code='WORKER_HEARTBEAT_TIMEOUT',error_message='Worker heartbeat expired.',run_after=now(),completed_at=CASE WHEN attempts < max_attempts AND retryable THEN NULL ELSE now() END,updated_at=now() WHERE workspace_id=$1 AND status='running' AND last_heartbeat < now() - ($2::int * interval '1 millisecond')",[tenantId,timeoutMs])); }
}
