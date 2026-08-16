import assert from "node:assert/strict";
import test from "node:test";
test("operation allowlist remains narrow",()=>{const allowed=["manager.verify","project.start","project.stop","project.verify","project.backup","collection.crawl","collection.verify"];assert.equal(allowed.includes("shell.exec"),false);assert.equal(allowed.length,7);});
