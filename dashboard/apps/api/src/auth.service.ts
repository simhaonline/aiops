import { Injectable, CanActivate, ExecutionContext, UnauthorizedException, ForbiddenException } from "@nestjs/common";
import type { FastifyRequest } from "fastify";
import { DatabaseService } from "./database.service";

export type AuthContext = { subject: string; tenantId: string; role: "owner"|"admin"|"operator"|"viewer" };

@Injectable()
export class WorkspaceAuthGuard implements CanActivate {
  constructor(private readonly database?: DatabaseService) {}
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<FastifyRequest & { auth?: AuthContext }>();
    const expected = process.env.AIOPS_DASHBOARD_TOKEN?.trim();
    const provided = String(request.headers["x-aiops-dashboard-token"] ?? "");
    const tenantId = String(process.env.AIOPS_TENANT_ID ?? "").trim();
    if (!expected || !provided || !constantTimeEqual(expected, provided)) throw new UnauthorizedException("Authentication required.");
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(tenantId)) throw new UnauthorizedException("AIOPS_TENANT_ID must be configured for private API access.");
    request.auth = { subject: String(request.headers["x-aiops-actor"] ?? "dashboard-operator").slice(0, 320), tenantId, role: roleFromEnv() };
    if (this.database?.configured()) {
      const membership = await this.database.query("SELECT role FROM app.memberships WHERE tenant_id=$1 AND subject=$2 LIMIT 1", [tenantId, request.auth.subject]);
      if (!membership.rowCount) throw new ForbiddenException("You are not a member of this workspace.");
      const role = String(membership.rows[0]?.role ?? "");
      if (role === "owner" || role === "admin" || role === "operator" || role === "viewer") request.auth.role = role;
    }
    return true;
  }
}

export function requireRole(request: FastifyRequest & { auth?: AuthContext }, roles: AuthContext["role"][]) {
  if (!request.auth || !roles.includes(request.auth.role)) throw new ForbiddenException("You do not have permission for this action.");
  return request.auth;
}

function roleFromEnv(): AuthContext["role"] { const role = process.env.AIOPS_DASHBOARD_ROLE; return role === "owner" || role === "admin" || role === "operator" ? role : "viewer"; }
function constantTimeEqual(a: string, b: string) { if (a.length !== b.length) return false; let value = 0; for (let index = 0; index < a.length; index++) value |= a.charCodeAt(index) ^ b.charCodeAt(index); return value === 0; }
