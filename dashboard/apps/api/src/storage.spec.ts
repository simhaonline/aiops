import assert from "node:assert/strict";
import test from "node:test";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { StorageService } from "./storage.service";

test("filesystem storage stores and removes tenant-safe objects", async () => {
  const previousMode = process.env.AIOPS_STORAGE_MODE;
  const previousRoot = process.env.AIOPS_STORAGE_ROOT;
  process.env.AIOPS_STORAGE_MODE = "filesystem";
  process.env.AIOPS_STORAGE_ROOT = await mkdtemp(join(tmpdir(), "simha-storage-test-"));
  const storage = new StorageService();
  const stored = await storage.put("workspace/media/item.txt", Buffer.from("hello"), "text/plain");
  assert.equal(stored.size, 5);
  assert.equal((await storage.get(stored.key)).toString(), "hello");
  assert.equal(await storage.exists(stored.key), true);
  await storage.remove(stored.key);
  assert.equal(await storage.exists(stored.key), false);
  assert.throws(() => storage.validateKey("../secret"));
  if (previousMode === undefined) delete process.env.AIOPS_STORAGE_MODE; else process.env.AIOPS_STORAGE_MODE = previousMode;
  if (previousRoot === undefined) delete process.env.AIOPS_STORAGE_ROOT; else process.env.AIOPS_STORAGE_ROOT = previousRoot;
});
