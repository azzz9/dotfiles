import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS = join(ROOT, "skills");

function frontmatter(dir) {
	const text = readFileSync(join(SKILLS, dir, "SKILL.md"), "utf8");
	const close = text.indexOf("\n---\n", 4);
	return text.slice(4, close);
}

test("a vendored skill keeps its upstream license beside it", () => {
	for (const entry of readdirSync(SKILLS, { withFileTypes: true })) {
		if (!entry.isDirectory() || !existsSync(join(SKILLS, entry.name, "SKILL.md"))) continue;
		if (!/^\s+upstream:/m.test(frontmatter(entry.name))) continue;
		assert.ok(
			existsSync(join(SKILLS, entry.name, "LICENSE")),
			`${entry.name}: vendored skill has no LICENSE`,
		);
	}
});

test("the vendored imozuru scripts parse and verify their demo", (t) => {
	const skill = join(SKILLS, "imozuru");
	const scripts = readdirSync(join(skill, "scripts"))
		.filter((name) => name.endsWith(".py"))
		.map((name) => join(skill, "scripts", name));
	const python = spawnSync("python3", ["-V"]);
	if (python.error) return t.skip("python3 is not installed");

	const parse = spawnSync(
		"python3",
		["-c", "import ast, sys; [ast.parse(open(p, encoding='utf-8').read()) for p in sys.argv[1:]]", ...scripts],
		{ encoding: "utf8" },
	);
	assert.equal(parse.status, 0, parse.stderr);

	const check = spawnSync(
		"python3",
		[join(skill, "scripts", "report.py"), join(skill, "examples", "demo"), "--check"],
		{ encoding: "utf8" },
	);
	assert.equal(check.status, 0, check.stderr || check.stdout);
});

test("the vendored yomiyasu keeps its license and vendor record", () => {
	const dir = join(SKILLS, "yomiyasu");
	for (const file of ["SKILL.md", "LICENSE", "UNICODE-LICENSE.txt", "VENDOR.md"]) {
		assert.ok(existsSync(join(dir, file)), `yomiyasu: missing ${file}`);
	}
	assert.ok(!existsSync(join(dir, "GUIDE.md")), "yomiyasu: GUIDE.md is not a skill file");
});
