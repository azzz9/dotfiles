# The pstack role table, one row per machine. The extension reads it from
# ~/.pi/agent/pstack/models.json at every agent start and appends the rows it
# finds to the system prompt, so a role left out costs no prompt space and just
# inherits the session model.
#
# The table has to arrive as a regular file. pstack's loadConfig rejects anything
# lstatSync() does not report as a file, so a Home Manager symlink is ignored and
# every role silently falls back to inherit-parent. modules/pi.nix copies the
# generated JSON in an activation script for that reason, and the copy is what
# makes a local /setup-pstack edit, or a `/pstack off`, give way to this file on
# the next switch.
{ pkgs }:
let
  # nix-desktop and nix-server carry the same two accounts, so they share one
  # table. Codex is the ChatGPT Plus quota, the scarcer resource: it takes the
  # judgment roles, one call each. Everything that runs in parallel or in bulk
  # stays on ollama-cloud, which bills per token across a 1M context.
  ollamaAndCodex = {
    # Bulk code work. Pinned rather than inherited, so a /model switch in the
    # parent does not move the cost of every delegate.
    "feature, refactoring" = "ollama-cloud/deepseek-v4.1-flash";
    "bug-fix" = "ollama-cloud/deepseek-v4.1-flash";
    "perf-issue" = "ollama-cloud/deepseek-v4.1-flash";
    "how explorer" = "ollama-cloud/deepseek-v4.1-flash";
    "reflect tooling" = "ollama-cloud/deepseek-v4.1-flash";
    # A hillclimb loops on one metric, so it stays on the bulk pin and runs as
    # many iterations as it needs.
    "hillclimb" = "ollama-cloud/deepseek-v4.1-flash";
    # Parallel readers, one call per angle.
    "why investigators" = "ollama-cloud/glm-5.3-flash";
    "swarm workers" = [
      "ollama-cloud/deepseek-v4.1-flash"
      "ollama-cloud/glm-5.3-flash"
    ];
    # Judgment, one call each, where a wrong call is expensive.
    "judgment and prose" = "openai-codex/gpt-6.1-sol";
    "hardest tasks" = "openai-codex/gpt-6.1-sol";
    "why synthesizer" = "openai-codex/gpt-6.1-sol";
    "how explainer" = "openai-codex/gpt-6-luna";
    "reflect judgment, divergent, synthesizer" = "openai-codex/gpt-6-luna";
    # A bakeoff, a cross-check, or a review wants different lineages, not the
    # strongest model twice.
    "arena runners" = [
      "ollama-cloud/deepseek-v4.1-flash"
      "ollama-cloud/kimi-k2.7-code"
      "openai-codex/gpt-6-luna"
    ];
    "arena cross-judge pool" = [
      "openai-codex/gpt-6.1-sol"
      "ollama-cloud/glm-5.3"
    ];
    "architect runners" = [
      "openai-codex/gpt-6.1-sol"
      "ollama-cloud/deepseek-v4.1-flash"
    ];
    "interrogate reviewers" = [
      "openai-codex/gpt-6.1-sol"
      "ollama-cloud/glm-5.3"
      "ollama-cloud/kimi-k2.7-code"
    ];
  };
  # The macbook runs on Copilot Enterprise, and that plan includes model choice,
  # so this row names explicit ids. pi's inherited catalog carries them as
  # `github-copilot/<id>`, and their prices match GitHub's models-and-pricing
  # table. Auto selection is optional there, not forced, and the monthly
  # AI-credit pool is what these pins spend.
  # https://docs.github.com/ja/copilot/get-started/plans (Models)
  # Copilot Free and Copilot Student are the plans that cannot name a model, so
  # this row does not transfer to them: an explicit slug is answered with 400
  # model_not_supported.
  copilot = {
    # Bulk code work at $0.10/$0.50 per 1M across a 1M context, the cheapest
    # tier Copilot serves with room for a whole repo in the prompt.
    "feature, refactoring" = "github-copilot/gpt-6-luna";
    "bug-fix" = "github-copilot/gpt-6-luna";
    "perf-issue" = "github-copilot/gpt-6-luna";
    "how explorer" = "github-copilot/gpt-6-luna";
    "reflect tooling" = "github-copilot/gpt-6-luna";
    # A hillclimb loops on one metric, so it gets the frontier tier.
    "hillclimb" = "github-copilot/gpt-6.1-sol";
    # Parallel readers, one call per angle, so they stay on the cheap pin.
    "why investigators" = "github-copilot/gpt-6-luna";
    # Many workers run at once, so the pool stays on the cheap pin.
    "swarm workers" = [ "github-copilot/gpt-6-luna" ];
    # Judgment, one call each, where a wrong call is expensive.
    "judgment and prose" = "github-copilot/claude-opus-5.5";
    "hardest tasks" = "github-copilot/claude-opus-5.5";
    "why synthesizer" = "github-copilot/claude-opus-5.5";
    "how explainer" = "github-copilot/gpt-6-luna";
    "reflect judgment, divergent, synthesizer" = "github-copilot/gpt-6-luna";
    # A bakeoff, a cross-check, or a review wants different models rather than
    # the strongest one twice. The macbook stays on Claude and GPT, so those two
    # lineages are what separates them.
    "arena runners" = [
      "github-copilot/gpt-6-luna"
      "github-copilot/claude-sonnet-5.5"
      "github-copilot/gpt-6.1-sol"
    ];
    "arena cross-judge pool" = [
      "github-copilot/claude-opus-5.5"
      "github-copilot/gpt-6.1-sol"
    ];
    "architect runners" = [
      "github-copilot/claude-opus-5.5"
      "github-copilot/claude-sonnet-5.5"
    ];
    "interrogate reviewers" = [
      "github-copilot/claude-opus-5.5"
      "github-copilot/gpt-6.1-sol"
      "github-copilot/claude-sonnet-5.5"
    ];
  };

  # ROLE_NAMES in extensions/pstack/config.ts owns this list. pstack ignores a
  # role name or a slug it cannot use, in silence, so a typo would only show up
  # as a delegate on the wrong model.
  roleNames = [
    "feature, refactoring"
    "bug-fix"
    "perf-issue"
    "hillclimb"
    "judgment and prose"
    "hardest tasks"
    "how explorer"
    "how explainer"
    "why investigators"
    "why synthesizer"
    "reflect tooling"
    "reflect judgment, divergent, synthesizer"
    "arena runners"
    "arena cross-judge pool"
    "swarm workers"
    "architect runners"
    "interrogate reviewers"
  ];

  isSlug = value:
    builtins.isString value && builtins.match "[^/[:space:]]+/[^/[:space:]]+" value != null;

  models = {
    nix-desktop = ollamaAndCodex;
    nix-server = ollamaAndCodex;
    macbook = copilot;
  };

  # Every problem in one list, so the assert in modules/pi.nix can print them
  # together and a row for one machine still fails the evaluation of another.
  problemsFor = models:
    builtins.concatMap
      (machine:
        let
          row = models.${machine};
        in
        builtins.concatMap
          (role:
            if !(builtins.elem role roleNames) then
              [ "${machine}: unknown role \"${role}\"" ]
            else
              let
                value = row.${role};
                slugs = if builtins.isList value then value else [ value ];
              in
              if slugs == [ ] || !(builtins.all isSlug slugs) then
                [ "${machine}: ${role} is not a provider/id slug: ${builtins.toJSON value}" ]
              else
                [ ])
          (builtins.attrNames row))
      (builtins.attrNames models);

  jsonFor = machine: (pkgs.formats.json { }).generate "pstack-models-${machine}.json" {
    version = 1;
    roles = models.${machine};
    skillsEnabled = true;
  };

  installFor = machine: pkgs.writeShellScript "pstack-models-${machine}" ''
    set -euo pipefail
    target="''${HOME:?HOME is unset}/.pi/agent/pstack"
    ${pkgs.coreutils}/bin/install -d -m 700 "$target"
    # Replace rather than overwrite: a leftover symlink would send the write to a
    # read-only store path.
    rm -f "$target/models.json"
    ${pkgs.coreutils}/bin/install -m 600 ${jsonFor machine} "$target/models.json"
  '';
in
{
  inherit roleNames models problemsFor jsonFor installFor;
}
