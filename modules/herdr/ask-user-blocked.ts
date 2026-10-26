import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const askTool = "ask_user_question";
const herdrBlockedEvent = "herdr:blocked";
const maxLabelChars = 80;

type AskInput = {
  questions?: ReadonlyArray<{ question?: string; header?: string }>;
};

function clean(text: string | undefined): string {
  return (text ?? "")
    .replace(/[\u0000-\u001f\u007f-\u009f]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function promptLabel(input: unknown): string | undefined {
  const questions = (input as AskInput | undefined)?.questions ?? [];
  const first = questions[0];
  const body = clean(first?.header) || clean(first?.question);
  if (!body) return undefined;

  const suffix = questions.length > 1 ? ` +${questions.length - 1}` : "";
  const chars = Array.from(body);
  return chars.slice(0, Math.max(1, maxLabelChars - suffix.length)).join("") + suffix;
}

export default function (pi: ExtensionAPI): void {
  if (process.env.HERDR_ENV !== "1" || !process.env.HERDR_PANE_ID) return;

  let blocked = false;

  function release(): void {
    if (!blocked) return;
    blocked = false;
    pi.events.emit(herdrBlockedEvent, { active: false });
  }

  pi.on("tool_call", (event) => {
    if (event.toolName !== askTool) return;
    blocked = true;
    pi.events.emit(herdrBlockedEvent, { active: true, label: promptLabel(event.input) });
  });

  pi.on("tool_result", (event) => {
    if (event.toolName === askTool) release();
  });

  pi.on("agent_settled", () => release());
}
