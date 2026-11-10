import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS = join(ROOT, "skills");

const DISCOVERABLE = [
	"explain",
	"herdr",
	"hunk-review",
	"imozuru",
	"workspace",
];

const HIDDEN = ["retro", "yomiyasu"];

function frontmatter(dir) {
	const text = readFileSync(join(SKILLS, dir, "SKILL.md"), "utf8");
	assert.ok(text.startsWith("---\n"), `${dir}: missing opening frontmatter`);
	const close = text.indexOf("\n---\n", 4);
	assert.ok(close !== -1, `${dir}: missing closing frontmatter`);
	return text.slice(4, close);
}

function description(fm) {
	const inline = fm.match(/^description:\s*(.+)$/m)?.[1]?.trim();
	if (inline && !/^[|>]/.test(inline)) return inline;
	const lines = fm.split("\n");
	const start = lines.findIndex((line) => /^description:\s*[|>]/.test(line));
	if (start === -1) return "";
	const block = [];
	for (let i = start + 1; i < lines.length; i++) {
		const line = lines[i];
		if (!/^\s+/.test(line)) break;
		block.push(line.trim());
	}
	return block.join(" ");
}

function skills() {
	return readdirSync(SKILLS, { withFileTypes: true })
		.filter((entry) => entry.isDirectory())
		.map((entry) => entry.name)
		.filter((name) => existsSync(join(SKILLS, name, "SKILL.md")));
}

test("every skill can fire, and exactly the listed skills are fireable", () => {
	const fireable = [];
	for (const name of skills()) {
		const fm = frontmatter(name);
		const declared = fm.match(/^name:\s*(.+)$/m)?.[1]?.trim();
		const descriptionText = description(fm);
		assert.ok(declared, `${name}: frontmatter has no name`);
		assert.equal(declared, name, `${name}: name does not match its directory`);
		assert.ok(descriptionText && descriptionText.length > 20, `${name}: frontmatter has no usable description`);
		if (!/^disable-model-invocation:\s*true\s*$/m.test(fm)) fireable.push(name);
	}
	assert.deepEqual(fireable.sort(), DISCOVERABLE);
});

test("the catalog is exactly the visible and hidden skills", () => {
	assert.deepEqual(skills().sort(), [...DISCOVERABLE, ...HIDDEN].sort());
});

test("hidden skills are marked hidden", () => {
	for (const name of HIDDEN) {
		assert.match(frontmatter(name), /^disable-model-invocation:\s*true\s*$/m);
	}
});

test("no directory under skills/ is a half-made skill", () => {
	const strays = readdirSync(SKILLS, { withFileTypes: true })
		.filter((entry) => entry.isDirectory())
		.map((entry) => entry.name)
		.filter((name) => !existsSync(join(SKILLS, name, "SKILL.md")));
	assert.deepEqual(strays, [], "a directory without SKILL.md never fires");
});
