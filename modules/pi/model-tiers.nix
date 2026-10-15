# The delegation assignment, one row per machine. The four tier agents and the
# two names the ruleset calls directly, the PR reviewer and comment-sicko, get
# their model and their thinking effort here, so the agent definitions in the
# skills package stay provider-free.
#
# An agent with no row runs on the parent session model, which is the safe
# default for a host with no binding.
{ knownAgents }:
let
  # nix-desktop and nix-server carry the same accounts, so they share one row.
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
  # The catalog refreshes over the network: the snapshot built into pi 1.2.0
  # stops at claude-haiku-4.5, while pi.dev serves 5.5 for github-copilot.
  macbook = {
    fast = { model = "github-copilot/claude-haiku-5.5"; thinking = "max"; };
    standard = { model = "github-copilot/claude-sonnet-5.5"; thinking = "medium"; };
    intent = { model = "github-copilot/claude-opus-5.5"; thinking = "high"; };
    deep = { model = "github-copilot/claude-opus-5.5"; thinking = "high"; };
    reviewer = { model = "github-copilot/gpt-6.1-sol"; thinking = "high"; };
    comment-sicko = { model = "github-copilot/claude-haiku-5.5"; thinking = "max"; };
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

  problemsFor = table:
    builtins.concatMap
      (machine:
        builtins.concatMap
          (agent:
            let pin = table.${machine}.${agent}; in
            if !(builtins.elem agent knownAgents) then
              [ "${machine}: unknown agent ${agent}" ]
            else if !isSlug pin.model then
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
