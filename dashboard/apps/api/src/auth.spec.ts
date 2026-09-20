import assert from "node:assert/strict";
import test from "node:test";
import { WorkspaceAuthGuard } from "./auth.service";

const context = (headers: Record<string, string>) => ({ switchToHttp: () => ({ getRequest: () => ({ headers }) }) }) as never;

test("workspace guard rejects missing credentials and tenant context", async () => {
  const previousToken = process.env.AIOPS_DASHBOARD_TOKEN;
  const previousTenant = process.env.AIOPS_TENANT_ID;
  process.env.AIOPS_DASHBOARD_TOKEN = "development-secret";
  process.env.AIOPS_TENANT_ID = "";
  await assert.rejects(() => new WorkspaceAuthGuard().canActivate(context({ "x-aiops-dashboard-token": "development-secret" })));
  process.env.AIOPS_TENANT_ID = previousTenant ?? "";
  if (previousToken === undefined) delete process.env.AIOPS_DASHBOARD_TOKEN; else process.env.AIOPS_DASHBOARD_TOKEN = previousToken;
});

test("workspace guard attaches an actor for a valid tenant token", async () => {
  const previousToken = process.env.AIOPS_DASHBOARD_TOKEN;
  const previousTenant = process.env.AIOPS_TENANT_ID;
  process.env.AIOPS_DASHBOARD_TOKEN = "development-secret";
  process.env.AIOPS_TENANT_ID = "00000000-0000-4000-8000-000000000001";
  const request: { headers: Record<string, string>; auth?: unknown } = { headers: { "x-aiops-dashboard-token": "development-secret", "x-aiops-actor": "tester" } };
  const validContext = { switchToHttp: () => ({ getRequest: () => request }) } as never;
  assert.equal(await new WorkspaceAuthGuard().canActivate(validContext), true);
  assert.deepEqual(request.auth, { subject: "tester", tenantId: process.env.AIOPS_TENANT_ID, role: "viewer" });
  process.env.AIOPS_TENANT_ID = previousTenant ?? "";
  if (previousToken === undefined) delete process.env.AIOPS_DASHBOARD_TOKEN; else process.env.AIOPS_DASHBOARD_TOKEN = previousToken;
});
