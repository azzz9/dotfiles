import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const source = "dotfiles:pi-prompt";
const paneId = process.env.HERDR_PANE_ID;
const maxPromptChars = 80;
let sequence = Date.now() * 1000;

function normalizePrompt(text: string): string {
  const normalized = text
    .replace(/[\u0000-\u001f\u007f-\u009f]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return Array.from(normalized).slice(0, maxPromptChars).join("");
}

function latestUserText(ctx: ExtensionContext): string | undefined {
  const branch = ctx.sessionManager.getBranch();
  for (let index = branch.length - 1; index >= 0; index--) {
    const entry = branch[index];
    if (entry.type !== "message" || entry.message.role !== "user") continue;

    const content = entry.message.content;
    const text = typeof content === "string"
      ? content
      : content.filter((part) => part.type === "text").map((part) => part.text).join(" ");
    return normalizePrompt(text) || undefined;
  }
  return undefined;
}

function reportMetadata(
  pi: ExtensionAPI,
  prompt: string | undefined,
  gitBranch: string | undefined,
): void {
  if (!paneId) return;
  sequence += 1;
  const args = [paneId, "--source", source, "--seq", String(sequence)];
  for (const [key, value] of [["prompt", prompt], ["git_branch", gitBranch]] as const) {
    if (value) {
      args.push("--token", `${key}=${value}`);
    } else {
      args.push("--clear-token", key);
    }
  }
  void pi.exec("herdr", ["pane", "report-metadata", ...args], { timeout: 5_000 })
    .then(({ code }) => {
      if (code !== 0) console.error("Herdr metadata report failed.");
    })
    .catch(() => console.error("Herdr metadata report could not run."));
}

async function currentBranch(pi: ExtensionAPI, cwd: string): Promise<string | undefined> {
  try {
    const { code, stdout } = await pi.exec("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
      cwd,
      timeout: 2_000,
    });
    if (code !== 0) return undefined;
    const name = stdout.trim();
    return name && name !== "HEAD" ? name : undefined;
  } catch {
    return undefined;
  }
}

function report(pi: ExtensionAPI, ctx: ExtensionContext, prompt: string | undefined): void {
  void currentBranch(pi, ctx.cwd).then((branch) => reportMetadata(pi, prompt, branch));
}

export default function (pi: ExtensionAPI): void {
  pi.on("input", (event, ctx) => {
    if (event.source === "extension" || ctx.mode !== "tui") return;
    report(pi, ctx, normalizePrompt(event.text) || undefined);
  });

  const restore = (ctx: ExtensionContext): void => {
    if (ctx.mode !== "tui") return;
    report(pi, ctx, latestUserText(ctx));
  };

  pi.on("session_start", (_event, ctx) => restore(ctx));
  pi.on("session_tree", (_event, ctx) => restore(ctx));
}
