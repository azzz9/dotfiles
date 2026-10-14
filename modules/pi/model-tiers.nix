# The delegation assignment, one row per machine. pi-subagents ships four tier
# agents, fast, standard, deep, and intent, and none of them pins a model. This
# file is where each one gets a model and a thinking effort, so the agent
# definitions stay provider-free. Two names the ruleset calls directly, the PR
# reviewer and comment-sicko, take the same two fields.
#
# An agent with no row runs on the parent session model, which is the safe
# default for a host with no binding.
let
  # nix-desktop and nix-server carry the same accounts, so they share one row.
  # glm-5.3 takes the tiers where a wrong call is expensive, and the effort
  # carries the depth on the two rows that stay on the bulk pin.
  desktop = {
    fast = { model = "ollama-cloud/deepseek-v4.1-flash"; thinking = "xhigh"; };
    standard = { model = "ollama-cloud/glm-5.3-flash"; thinking = "xhigh"; };
    intent = { model = "ollama-cloud/glm-5.3"; thinking = "xhigh"; };
    deep = { model = "ollama-cloud/glm-5.3"; thinking = "xhigh"; };
    reviewer = { model = "openai-codex/gpt-6.1-sol"; thinking = "high"; };
    comment-sicko = { model = "ollama-cloud/deepseek-v4.1-flash"; thinking = "xhigh"; };
  };

  # The macbook runs on Copilot Enterprise, which includes model choice, so this
  # row names explicit ids. Copilot Free and Copilot Student cannot name a model
  # and answer an explicit slug with 400 model_not_supported, so the row does not
  # transfer to them. https://docs.github.com/ja/copilot/get-started/plans
  # Haiku 5.5 is not in pi's catalog, so 4.5 carries the cheap rows.
  macbook = {
    fast = { model = "github-copilot/claude-haiku-4.5"; thinking = "max"; };
    standard = { model = "github-copilot/claude-sonnet-5.5"; thinking = "medium"; };
    intent = { model = "github-copilot/claude-opus-5.5"; thinking = "high"; };
    deep = { model = "github-copilot/claude-opus-5.5"; thinking = "high"; };
    reviewer = { model = "github-copilot/gpt-6.1-sol"; thinking = "high"; };
    comment-sicko = { model = "github-copilot/claude-haiku-4.5"; thinking = "max"; };
  };

  rows = {
    nix-desktop = desktop;
    nix-server = desktop;
    macbook = macbook;
  };

  thinkingLevels = [
    "off"
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];

  isSlug = value:
    builtins.isString value && builtins.match "[^/[:space:]]+/[^/[:space:]]+" value != null;

  # Every problem in one list, so the assert in modules/pi.nix can print them
  # together and a row for one machine still fails the evaluation of another.
  problemsFor = table:
    builtins.concatMap
      (machine:
        builtins.concatMap
          (agent:
            let pin = table.${machine}.${agent}; in
            if !isSlug pin.model then
              [ "${machine}: ${agent} is not a provider/id slug: ${builtins.toJSON pin.model}" ]
            else if !(builtins.elem pin.thinking thinkingLevels) then
              [ "${machine}: ${agent} thinking is not one of ${builtins.concatStringsSep ", " thinkingLevels}: ${builtins.toJSON pin.thinking}" ]
            else
              [ ])
          (builtins.attrNames table.${machine}))
      (builtins.attrNames table);

  subagentsFor = machine:
    let
      pins = rows.${machine};
    in
    {
      defaultThinking = "medium";
      agentOverrides = builtins.mapAttrs (_agent: pin: { inherit (pin) model thinking; }) pins;
    };
in
{
  inherit rows problemsFor subagentsFor;
}
