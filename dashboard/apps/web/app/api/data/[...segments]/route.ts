import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

type Params = { segments: string[] };
async function forward(request: NextRequest, { params }: { params: Promise<Params> }) {
  const { segments } = await params;
  const upstream = process.env.AIOPS_API_URL ?? "http://127.0.0.1:11081";
  const target = `${upstream}/api/${segments.map(segment => encodeURIComponent(segment)).join("/")}${request.nextUrl.search}`;
  const headers = new Headers();
  headers.set("x-aiops-dashboard-token", process.env.AIOPS_DASHBOARD_TOKEN ?? "");
  headers.set("x-aiops-actor", request.headers.get("x-aiops-actor") ?? "dashboard-user");
  const contentType = request.headers.get("content-type");
  if (contentType) headers.set("content-type", contentType);
  try {
    const response = await fetch(target, { method: request.method, headers, body: request.method === "GET" || request.method === "HEAD" ? undefined : await request.arrayBuffer(), cache: "no-store", signal: AbortSignal.timeout(15_000) });
    const body = await response.arrayBuffer();
    return new NextResponse(body, { status: response.status, headers: { "content-type": response.headers.get("content-type") ?? "application/json", "cache-control": "no-store" } });
  } catch {
    return NextResponse.json({ error: { code: "UPSTREAM_UNAVAILABLE", message: "The workspace service is unavailable." } }, { status: 503 });
  }
}
export const GET = forward;
export const POST = forward;
export const PATCH = forward;
export const DELETE = forward;
