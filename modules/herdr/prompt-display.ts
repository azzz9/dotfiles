import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const source = "dotfiles:pi-prompt";
const paneId = process.env.HERDR_PANE_ID;
const maxPromptChars = 80;
let sequence = Date.now() * 1000;

type PromptReport =
  | { kind: "set"; text: string }
  | { kind: "clear" };

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

function reportPrompt(pi: ExtensionAPI, prompt: PromptReport): void {
  if (!paneId) return;
  sequence += 1;
  const args = [paneId, "--source", source, "--seq", String(sequence)];
  if (prompt.kind === "set") {
    args.push("--token", `prompt=${prompt.text}`);
  } else {
    args.push("--clear-token", "prompt");
  }
  void pi.exec("herdr", ["pane", "report-metadata", ...args], { timeout: 5_000 })
    .then(({ code }) => {
      if (code !== 0) console.error("Herdr prompt metadata report failed.");
    })
    .catch(() => console.error("Herdr prompt metadata report could not run."));
}

export default function (pi: ExtensionAPI): void {
  pi.on("input", (event, ctx) => {
    if (event.source === "extension" || ctx.mode !== "tui") return;
    const prompt = normalizePrompt(event.text);
    reportPrompt(pi, prompt ? { kind: "set", text: prompt } : { kind: "clear" });
  });

  const restorePrompt = (ctx: ExtensionContext): void => {
    if (ctx.mode !== "tui") return;
    const prompt = latestUserText(ctx);
    reportPrompt(pi, prompt ? { kind: "set", text: prompt } : { kind: "clear" });
  };

  pi.on("session_start", (_event, ctx) => restorePrompt(ctx));
  pi.on("session_tree", (_event, ctx) => restorePrompt(ctx));
}
