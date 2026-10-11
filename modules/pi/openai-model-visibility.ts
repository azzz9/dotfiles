import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type VisibilityRule =
  | { mode: "allow"; modelIds: ReadonlySet<string> }
  | { mode: "deny"; modelIds: ReadonlySet<string> };

const visibilityRules: ReadonlyMap<string, VisibilityRule> = new Map([
  ["openai", { mode: "allow", modelIds: new Set<string>() }],
  ["openai-codex", { mode: "allow", modelIds: new Set(["gpt-6.1-sol", "gpt-6-luna"]) }],
  ["ollama-cloud", { mode: "deny", modelIds: new Set(["kimi-k3"]) }],
]);

function filterVisibleModels<T extends { id: string }>(models: T[], rule: VisibilityRule): T[] {
  return models.filter((model) => {
    switch (rule.mode) {
      case "allow":
        return rule.modelIds.has(model.id);
      case "deny":
        return !rule.modelIds.has(model.id);
      default: {
        const exhaustive: never = rule;
        return exhaustive;
      }
    }
  });
}

export default function (pi: ExtensionAPI) {
  const unsubscribe = pi.on("session_start", async (_event, ctx) => {
    await ctx.modelRegistry.refresh({ allowNetwork: false });
    for (const [providerId, rule] of visibilityRules) {
      const provider = ctx.modelRegistry.getProvider(providerId);
      if (!provider) throw new Error(`Provider ${providerId} is unavailable.`);
      pi.registerProvider({
        ...provider,
        filterModels(models, credential) {
          const available = provider.filterModels?.(models, credential) ?? models;
          return filterVisibleModels(available, rule);
        },
        filterAllModels(models, credential) {
          const available = provider.filterAllModels?.(models, credential) ?? models;
          return filterVisibleModels(available, rule);
        },
      });
    }
    await ctx.modelRegistry.refresh({ allowNetwork: false });
    unsubscribe();
  });
  pi.on("session_shutdown", (event) => {
    if (event.reason !== "reload") return;
    for (const providerId of visibilityRules.keys()) pi.unregisterProvider(providerId);
  });
}
