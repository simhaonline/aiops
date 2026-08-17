import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const body = await request.json().catch(() => ({}));
  const prompt = String(body?.prompt ?? "").trim();
  if (!prompt) return NextResponse.json({ error: "Prompt is required." }, { status: 400 });
  try {
    const response = await fetch(`${process.env.AIOPS_API_URL ?? "http://127.0.0.1:11081"}/api/q-ai/evaluate`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-aiops-dashboard-token": process.env.AIOPS_DASHBOARD_TOKEN ?? "" },
      body: JSON.stringify({ prompt, task: body?.mode ?? "text" }),
      cache: "no-store",
      signal: AbortSignal.timeout(60_000),
    });
    const payload = await response.json().catch(() => ({ error: "AI service returned an invalid response." }));
    if (!response.ok) return NextResponse.json({ error: payload?.message ?? payload?.error ?? "AI service is unavailable." }, { status: response.status });
    return NextResponse.json({ reply: payload });
  } catch {
    return NextResponse.json({ error: "AI service could not be reached." }, { status: 502 });
  }
}
