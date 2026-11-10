import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS = join(ROOT, "skills");
const AGENTS = join(ROOT, "agents");

test("the always-on rules carry no delegation rule", () => {
	const append = readFileSync(join(ROOT, "APPEND_SYSTEM.md"), "utf8");
	assert.ok(!/^## Orchestrator$/m.test(append), "APPEND still has the orchestrator section");
	assert.doesNotMatch(append, /^## Delegation$/m);
	assert.doesNotMatch(append, /comment-sicko/);
});

test("there is no local subagent", () => {
	const local = existsSync(AGENTS)
		? readdirSync(AGENTS).filter((name) => name.endsWith(".md"))
		: [];
	assert.deepEqual(local, []);
	const append = readFileSync(join(ROOT, "APPEND_SYSTEM.md"), "utf8");
	assert.doesNotMatch(append, /comment-sicko/);
});

test("imozuru does not delegate search to a subagent", () => {
	const text = readFileSync(join(SKILLS, "imozuru", "SKILL.md"), "utf8");
	assert.doesNotMatch(text, /検索役のサブエージェント/);
	assert.match(text, /サブエージェントは使わない/);
});

test("every mode names an agent or no subagent", () => {
	for (const name of ["workspace"]) {
		const text = readFileSync(join(SKILLS, name, "SKILL.md"), "utf8");
		const modes = text.split("## Modes")[1]?.split("##")[0] ?? "";
		assert.ok(modes.trim(), `${name}: missing ## Modes`);
		const lines = modes.split("\n").filter((line) => /^- \*\*/.test(line));
		assert.ok(lines.length > 0, `${name}: no mode lines`);
		for (const line of lines) {
			assert.match(line, /\((?:[^)]*)(?:no subagent|reviewer|pstack:thermo-nuclear-review-subagent)[^)]*\)/, `${name}: ${line}`);
		}
	}
});
