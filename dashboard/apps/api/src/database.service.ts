import { Injectable, OnModuleDestroy } from "@nestjs/common";
import { Pool, PoolConfig } from "pg";

/** Optional database boundary. The dashboard remains usable in read-only mode
 * when AIOPS_DATABASE_URL is not configured, while SaaS deployments get a
 * bounded, tenant-aware PostgreSQL connection pool. */
@Injectable()
export class DatabaseService implements OnModuleDestroy {
  private readonly pool?: Pool;

  constructor() {
    const url = process.env.AIOPS_DATABASE_URL?.trim();
    if (!url) return;
    const config: PoolConfig = {
      connectionString: url,
      max: Math.min(Math.max(Number(process.env.AIOPS_DATABASE_POOL_MAX ?? 10), 1), 50),
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 3_000,
      statement_timeout: 15_000,
      query_timeout: 20_000,
      ssl: process.env.AIOPS_DATABASE_SSL === "require" ? { rejectUnauthorized: true } : undefined,
    };
    this.pool = new Pool(config);
  }

  configured(): boolean { return Boolean(this.pool); }

  async health(): Promise<{ configured: boolean; connected: boolean }> {
    if (!this.pool) return { configured: false, connected: false };
    try {
      await this.pool.query("select 1");
      return { configured: true, connected: true };
    } catch {
      return { configured: true, connected: false };
    }
  }

  async query<T extends Record<string, unknown> = Record<string, unknown>>(text: string, values: readonly unknown[] = []) {
    if (!this.pool) throw new Error("AIOPS_DATABASE_URL is not configured");
    return this.pool.query<T>(text, values as unknown[]);
  }

  async onModuleDestroy() { await this.pool?.end(); }
}
