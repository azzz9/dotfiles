import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const promptEvent = "rpiv:ask-user:prompt";
const blockedEvent = "rpiv:ask-user:blocked";
const herdrBlockedEvent = "herdr:blocked";
const maxLabelChars = 80;

type PromptPayload = {
  questions?: ReadonlyArray<{ question?: string; header?: string }>;
};

function clean(text: string | undefined): string {
  return (text ?? "")
    .replace(/[\u0000-\u001f\u007f-\u009f]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function promptLabel(payload: unknown): string | undefined {
  const questions = (payload as PromptPayload | undefined)?.questions ?? [];
  const first = questions[0];
  const body = clean(first?.header) || clean(first?.question);
  if (!body) return undefined;

  const suffix = questions.length > 1 ? ` +${questions.length - 1}` : "";
  const chars = Array.from(body);
  return chars.slice(0, Math.max(1, maxLabelChars - suffix.length)).join("") + suffix;
}

export default function (pi: ExtensionAPI): void {
  if (process.env.HERDR_ENV !== "1" || !process.env.HERDR_PANE_ID) return;

  let label: string | undefined;

  pi.events.on(promptEvent, (payload: unknown) => {
    label = promptLabel(payload);
  });

  // herdr-agent-state.ts, written by `herdr integration install pi`, reports
  // this event's state through the socket. rpiv-ask-user-question emits its
  // own pair around the questionnaire, so this bridges the two.
  pi.events.on(blockedEvent, (payload: unknown) => {
    const active = (payload as { active?: boolean } | undefined)?.active === true;
    pi.events.emit(herdrBlockedEvent, { active, label: active ? label : undefined });
    if (!active) label = undefined;
  });
}
