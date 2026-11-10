import { stat } from "node:fs/promises";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MUTATING = new Set(["bash", "edit", "write"]);
const IGNORED = [".pi"];
const MAX_PATHS = 8;

export type Snapshot = Map<string, string>;

function ignored(path: string): boolean {
	return IGNORED.some((prefix) => path === prefix || path.startsWith(`${prefix}/`));
}

export function parseStatus(stdout: string): string[] {
	const paths: string[] = [];
	const records = stdout.split("\0");

	for (let index = 0; index < records.length; index += 1) {
		const record = records[index];
		if (record.length < 4) continue;

		const status = record.slice(0, 2);
		const path = record.slice(3);
		const renamed = status[0] === "R" || status[0] === "C";
		const oldPath = renamed ? records[index + 1] : undefined;
		if (renamed) index += 1;

		if (!ignored(path)) paths.push(path);
		if (oldPath && !ignored(oldPath)) paths.push(oldPath);
	}

	return paths;
}

export async function snapshot(pi: ExtensionAPI, root: string): Promise<Snapshot | undefined> {
	const { stdout, code } = await pi.exec("git", ["status", "--porcelain=v1", "-z", "--untracked-files=all"], {
		cwd: root,
	});
	if (code !== 0) return undefined;

	const files: Snapshot = new Map();
	for (const path of parseStatus(stdout)) {
		const info = await stat(join(root, path)).catch(() => undefined);
		files.set(path, info ? `${info.mtimeMs}:${info.size}` : "missing");
	}
	return files;
}

export function changedPaths(before: Snapshot, after: Snapshot): string[] {
	const paths: string[] = [];
	for (const [path, signature] of after) {
		if (before.get(path) !== signature) paths.push(path);
	}
	for (const path of before.keys()) {
		if (!after.has(path)) paths.push(path);
	}
	return paths;
}

function note(paths: string[]): string {
	const lines = paths.slice(0, MAX_PATHS).map((path) => `- ${path}`);
	if (paths.length > MAX_PATHS) lines.push(`- and ${paths.length - MAX_PATHS} more`);
	return [
		"Files changed outside this session since its last turn:",
		...lines,
		"Re-read them before editing. Do not assume an earlier read is current.",
	].join("\n");
}

export default function externalChanges(pi: ExtensionAPI) {
	let root: string | undefined;
	let baseline: Snapshot | undefined;

	pi.on("session_start", async (_event, ctx) => {
		const top = await pi.exec("git", ["rev-parse", "--show-toplevel"], { cwd: ctx.cwd }).catch(() => undefined);
		root = top?.code === 0 ? top.stdout.trim() : undefined;
		baseline = root ? await snapshot(pi, root) : undefined;
	});

	pi.on("tool_result", async (event) => {
		if (!root || !baseline || !MUTATING.has(event.toolName)) return;
		const next = await snapshot(pi, root);
		if (next) baseline = next;
	});

	pi.on("before_agent_start", async () => {
		if (!root || !baseline) return;
		const next = await snapshot(pi, root);
		if (!next) return;

		const paths = changedPaths(baseline, next);
		baseline = next;
		if (paths.length === 0) return;

		return {
			message: {
				customType: "external-changes",
				content: note(paths),
				display: true,
			},
		};
	});
}
