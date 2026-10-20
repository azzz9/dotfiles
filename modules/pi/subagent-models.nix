# The reviewer is the only subagent; each machine gets its model and thinking.
{ knownAgents }:
let
  # nix-desktop and nix-server carry the same accounts, so they share one row.
  desktop = {
    reviewer = { model = "openai-codex/gpt-6.1-sol"; thinking = "high"; };
  };

  # The macbook runs on Copilot Enterprise, which includes model choice, so this
  # row names explicit ids. Copilot Free and Copilot Student cannot name a model
  # and answer an explicit slug with 400 model_not_supported, so the row does not
  # transfer to them. https://docs.github.com/ja/copilot/get-started/plans
  # The catalog refreshes over the network. The snapshot built into pi 1.2.0
  # stops at claude-haiku-4.5, while pi.dev serves 5.5 for github-copilot.
  macbook = {
    reviewer = { model = "github-copilot/gpt-6.1-sol"; thinking = "high"; };
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
