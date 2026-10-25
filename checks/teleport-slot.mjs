import assert from "node:assert/strict";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { agentSlotRollbackArgs, selectAgentSlot } from "./src/core.ts";

const target = mkdtempSync(join(tmpdir(), "teleport-slot-"));
const tabs = [
  { tab_id: "t4", number: 4, pane_count: 1, label: "pi" },
  { tab_id: "t1", number: 1, pane_count: 1, label: "agent" },
];
const panes = [
  { tab_id: "t4", pane_id: "p4", cwd: target },
  { tab_id: "t1", pane_id: "p1", cwd: target },
];

assert.deepEqual(
  selectAgentSlot(tabs, panes, target),
  { tabId: "t1", paneId: "p1", label: "agent" },
  "the first tab by number wins even when tab list starts with the active tab",
);

panes[1].cwd = "/";
assert.equal(selectAgentSlot(tabs, panes, target), undefined, "a shell outside the target is not borrowed");
panes[1].cwd = target;

tabs[1].pane_count = 2;
assert.equal(selectAgentSlot(tabs, panes, target), undefined, "a tab with more than one pane is not borrowed");
tabs[1].pane_count = 1;

assert.deepEqual(
  agentSlotRollbackArgs("p1", "t1", "agent"),
  [["pane", "send-keys", "p1", "ctrl+c", "ctrl+c"], ["tab", "rename", "t1", "agent"]],
  "rollback stops Pi before restoring the label",
);

console.log("teleport-slot: ok");
