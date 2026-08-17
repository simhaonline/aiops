import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

const MAX_BYTES = 25 * 1024 * 1024;

export async function POST(request: Request) {
  const form = await request.formData().catch(() => null);
  const value = form?.get("file");
  if (!(value instanceof File)) return NextResponse.json({ error: "Choose a file to upload." }, { status: 400 });
  if (value.size > MAX_BYTES) return NextResponse.json({ error: "Files must be 25 MB or smaller." }, { status: 413 });
  const safeName = path.basename(value.name).replace(/[^a-zA-Z0-9._-]/g, "-") || "upload.bin";
  const id = `${Date.now()}-${crypto.randomUUID()}`;
  const dir = "/tmp/aiops-uploads";
  await mkdir(dir, { recursive: true, mode: 0o700 });
  await writeFile(path.join(dir, `${id}-${safeName}`), Buffer.from(await value.arrayBuffer()), { mode: 0o600 });
  return NextResponse.json({ name: value.name, size: value.size, type: value.type || "application/octet-stream", status: "quarantined" }, { status: 201 });
}
