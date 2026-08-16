import assert from "node:assert/strict";
import test from "node:test";
import { WorkspaceController } from "./workspace.controller";

test("workspace publishes every supported modality", () => {
  const workspace = new WorkspaceController().capabilities();
  assert.deepEqual(workspace.modalities.map((item) => item.id), [
    "text", "code", "document", "image", "video", "voice", "translation"
  ]);
});

test("registry content cannot auto-install", () => {
  const workspace = new WorkspaceController().capabilities();
  assert.equal(workspace.registry.autoInstall, false);
  assert.equal(workspace.safety.uploads, "quarantine-first");
  assert.equal(workspace.safety.publicArtifacts, "manual-approval");
});
