import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { appendFile, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { promisify } from "node:util";

import { changedPaths, parseStatus, snapshot } from "../extensions/external-changes.ts";

const exec = promisify(execFile);

async function git(cwd, ...args) {
	await exec("git", args, { cwd, encoding: "utf8" });
}

const fakePi = {
	async exec(command, args, options) {
		try {
			const { stdout, stderr } = await exec(command, args, { ...options, encoding: "utf8" });
			return { stdout, stderr, code: 0 };
		} catch (error) {
			return { stdout: error.stdout ?? "", stderr: error.stderr ?? "", code: error.code ?? 1 };
		}
	},
};

test("a rename into an ignored path does not invent a path", () => {
	assert.deepEqual(parseStatus("R  .pi/foo.ts\0foo.ts\0"), ["foo.ts"]);
});

test("a rename reports the old path as removed", () => {
	assert.deepEqual(parseStatus("R  new.ts\0old.ts\0"), ["new.ts", "old.ts"]);
});

test("an edit inside an untracked directory changes the snapshot", async () => {
	const root = await mkdtemp(join(tmpdir(), "pi-external-changes-"));
	try {
		await git(root, "init", "-q");
		await writeFile(join(root, "tracked.txt"), "one\n");
		await git(root, "add", "tracked.txt");
		await git(root, "-c", "user.name=test", "-c", "user.email=test@example.com", "commit", "-qm", "init");

		await mkdir(join(root, "dir"));
		const file = join(root, "dir", "file.txt");
		await writeFile(file, "one\n");

		const before = await snapshot(fakePi, root);
		assert.ok(before?.has("dir/file.txt"), "the snapshot lists the file, not its directory");

		await appendFile(file, "two\n");
		const after = await snapshot(fakePi, root);
		assert.ok(after);
		assert.deepEqual(changedPaths(before, after), ["dir/file.txt"]);
	} finally {
		await rm(root, { recursive: true, force: true });
	}
});
