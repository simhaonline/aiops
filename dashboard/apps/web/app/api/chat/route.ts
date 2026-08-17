import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const body = await request.json().catch(() => ({}));
  const prompt = String(body?.prompt ?? "").trim();
  if (!prompt) return NextResponse.json({ error: "Prompt is required." }, { status: 400 });
  try {
    const response = await fetch(`${process.env.Q_AI_GATEWAY_URL ?? "http://127.0.0.1:11434/v1"}/chat/completions`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ model: process.env.Q_AI_CHAT_MODEL ?? "qwen2.5:7b", messages: [{ role: "system", content: "You are SIMHA, a concise and practical AI workspace assistant." }, { role: "user", content: prompt }], temperature: 0.2 }),
      cache: "no-store",
      signal: AbortSignal.timeout(60_000),
    });
    const payload = await response.json().catch(() => ({ error: "AI service returned an invalid response." }));
    if (!response.ok) return NextResponse.json({ error: payload?.message ?? payload?.error ?? "AI service is unavailable." }, { status: response.status });
    return NextResponse.json({ reply: payload?.choices?.[0]?.message?.content ?? "The model returned an empty response.", model: payload?.model ?? process.env.Q_AI_CHAT_MODEL ?? "qwen2.5:7b" });
  } catch {
    return NextResponse.json({ error: "AI service could not be reached." }, { status: 502 });
  }
}
