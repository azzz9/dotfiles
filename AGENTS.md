# Dotfiles Repo — Project Instructions

Coding agents that work inside this repo read this file. The global rules live
in `config/ai/AGENTS.md`, deployed to `~/.pi/agent/AGENTS.md`; that file keeps
only the turn gate, the show-me gate, and the git rules.

## Repo-local skills

Two skills are not in the global skill list (to save tokens in other
projects). Read the SKILL.md directly when the situation applies:

| Situation | Read |
|-----------|------|
| Always read first when working in this repo | `config/ai/skills/dotfiles-context/SKILL.md` |
| Editing `.nix` files or running `nix` / `home-manager` commands | `config/ai/skills/nix-home-manager/SKILL.md` |
