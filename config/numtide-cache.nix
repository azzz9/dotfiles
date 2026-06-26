# Numtide binary cache settings for llm-agents.nix packages (e.g. codex).
# Referenced by modules/dotfiles.nix (isolated NIX_CONF_DIR).
#
# NOTE: flake.nix cannot `import` this file because Nix rejects a
# top-level `let ... in { ... }` in flake.nix ("must be an attribute
# set"), so it inlines a copy of these two values in its nixConfig.
# Keep both copies in sync when updating.
{
  url = "https://cache.numtide.com";
  key = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
}
