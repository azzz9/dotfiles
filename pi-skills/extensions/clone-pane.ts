import { execFile } from "node:child_process";
import { randomBytes } from "node:crypto";
import { existsSync } from "node:fs";
import { promisify } from "node:util";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const exec = promisify(execFile);
const MAX_BUFFER = 4 * 1024 * 1024;

type HerdrResponse = {
	result?: {
		pane?: {
			pane_id?: string;
		};
	};
};

async function herdr(args: string[], cwd: string): Promise<HerdrResponse> {
	const { stdout } = await exec("herdr", args, { cwd, encoding: "utf8", maxBuffer: MAX_BUFFER });
	const text = stdout.trim();
	return text ? (JSON.parse(text) as HerdrResponse) : {};
}

function errorText(error: unknown): string {
	const value = error as { stderr?: string; message?: string };
	return String(value.stderr ?? value.message ?? error).trim().slice(0, 240);
}

function cloneName(): string {
	return `clone-${randomBytes(3).toString("hex")}`;
}

async function startClone(paneId: string, name: string, sessionFile: string, cwd: string): Promise<void> {
	for (let attempt = 1; attempt <= 3; attempt += 1) {
		try {
			await herdr(["agent", "start", name, "--kind", "pi", "--pane", paneId, "--", "--fork", sessionFile], cwd);
			return;
		} catch (error) {
			if (attempt === 3 || !errorText(error).includes("agent_pane_busy")) throw error;
			await new Promise((resolve) => setTimeout(resolve, 400));
		}
	}
}

export default function clonePane(pi: ExtensionAPI) {
	pi.registerCommand("clone-pane", {
		description: "Copy this session into an adjacent Herdr pane and continue there. Optional argument: right or down.",
		handler: async (args, ctx) => {
			if (process.env.HERDR_ENV !== "1") {
				ctx.ui.notify("clone-pane needs Herdr.", "warning");
				return;
			}

			const sessionFile = ctx.sessionManager.getSessionFile();
			if (!sessionFile || !existsSync(sessionFile)) {
				ctx.ui.notify("clone-pane needs a saved session.", "warning");
				return;
			}

			const direction = args.trim().toLowerCase() === "down" ? "down" : "right";

			try {
				const split = await herdr(
					["pane", "split", "--current", "--direction", direction, "--cwd", ctx.cwd, "--focus"],
					ctx.cwd,
				);
				const paneId = split.result?.pane?.pane_id;
				if (!paneId) throw new Error("herdr returned no pane id");

				const name = cloneName();
				await startClone(paneId, name, sessionFile, ctx.cwd);
				ctx.ui.notify(`clone-pane: ${name} in ${paneId}`, "info");
			} catch (error) {
				ctx.ui.notify(`clone-pane failed: ${errorText(error)}`, "error");
			}
		},
	});
}
