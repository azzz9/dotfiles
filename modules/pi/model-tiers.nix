# The delegation tier table, one row per machine. pi-subagents ships four tier
# agents, fast, standard, deep, and intent, and none of them pins a model: the
# binding is `subagents.agentOverrides.<tier>.model` in settings.json. This file
# is where a machine's provider and quota land, so the agent definitions stay
# provider-free.
#
# The pins come from modules/pi/pstack-models.nix, the table the pstack extension
# reads today. A later change removes that extension and its table, and this
# import moves with them. Each tier takes the row whose role already means the
# same thing, so no machine changes model when the wiring does.
{ pkgs }:
let
  pstackModels = import ./pstack-models.nix { inherit pkgs; };

  # tier -> the role row that already carries that tier's meaning and cost.
  tierRole = {
    # Recon, lookups, and mechanical edits: the bulk pin.
    fast = "how explorer";
    # Most delegation: the bulk code pin, which is the same value as fast.
    standard = "feature, refactoring";
    # Hard work that arrives with an explicit goal: the top judgment pin.
    deep = "hardest tasks";
    # Ambiguous work where scoping is the task: the prose pin.
    intent = "how explainer";
  };

  # A tier agent is one child on one model, so a role that names a pool of
  # lineages takes its first entry.
  pinFor = row: role:
    let value = row.${role}; in
    if builtins.isList value then builtins.head value else value;

  # Both review agents are pinned rather than left to inherit the parent session
  # model, because a review is judgment that runs one call each. comment-sicko
  # reads a comment pass, which is cheaper than the diff review, so it takes the
  # standard pin.
  subagentsFor = machine:
    let
      tiers = builtins.mapAttrs (_tier: role: pinFor pstackModels.models.${machine} role) tierRole;
    in
    {
      defaultThinking = "medium";
      agentOverrides = builtins.mapAttrs (_tier: model: { inherit model; }) tiers // {
        reviewer = { model = tiers.deep; };
        comment-sicko = { model = tiers.standard; };
      };
    };
in
{
  inherit subagentsFor;
}
