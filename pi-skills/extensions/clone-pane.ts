import { execFile } from "node:child_process";
import { randomBytes } from "node:crypto";
import { existsSync } from "node:fs";
import { promisify } from "node:util";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const exec = promisify(execFile);
const MAX_BUFFER = 4 * 1024 * 1024;

type TuiosSplitResponse = {
	success?: boolean;
	error?: string;
	window_id?: string;
	pane_id?: string;
	id?: string;
};

async function tuiosSplit(args: string[], cwd: string): Promise<TuiosSplitResponse> {
	const { stdout } = await exec("tuios", args, { cwd, encoding: "utf8", maxBuffer: MAX_BUFFER });
	const text = stdout.trim();
	return text ? (JSON.parse(text) as TuiosSplitResponse) : {};
}

function errorText(error: unknown): string {
	const value = error as { stderr?: string; message?: string };
	return String(value.stderr ?? value.message ?? error).trim().slice(0, 240);
}

function cloneName(): string {
	return `clone-${randomBytes(3).toString("hex")}`;
}

export default function clonePane(pi: ExtensionAPI) {
	pi.registerCommand("clone-pane", {
		description: "Copy this session into an adjacent tuios pane and continue there. Optional argument: right or down.",
		handler: async (args, ctx) => {
			if (process.env.TUIOS_ENV !== "1") {
				ctx.ui.notify("clone-pane needs tuios.", "warning");
				return;
			}

			const sessionFile = ctx.sessionManager.getSessionFile();
			if (!sessionFile || !existsSync(sessionFile)) {
				ctx.ui.notify("clone-pane needs a saved session.", "warning");
				return;
			}

			const direction = args.trim().toLowerCase() === "down" ? "down" : "right";
			const name = cloneName();

			try {
				const split = await tuiosSplit(
					["split-window", direction, "--cwd", ctx.cwd, "--name", name, "--json", "--", "pi", "--fork", sessionFile],
					ctx.cwd,
				);
				if (split.success === false) {
					throw new Error(split.error || "tuios split-window failed");
				}
				const paneId = split.window_id ?? split.pane_id ?? split.id;
				ctx.ui.notify(paneId ? `clone-pane: ${name} in ${paneId}` : `clone-pane: ${name}`, "info");
			} catch (error) {
				ctx.ui.notify(`clone-pane failed: ${errorText(error)}`, "error");
			}
		},
	});
}
