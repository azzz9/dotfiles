# Dotfiles Repo — Project Instructions

Coding agents that work inside this repo read this file. The global rules live
in `config/ai/AGENTS.md`, deployed to `~/.pi/agent/AGENTS.md`; that file keeps
only the turn gate, the show-me gate, and the git rules.

## Repo-local skills

`dotfiles-context` and `nix-home-manager` live in `.agents/skills/` as
project-scoped pi skills, so they load only in this repo and cost no tokens
elsewhere. pi discovers them once the project is trusted; read the SKILL.md
directly when the situation applies:

| Situation | Read |
|-----------|------|
| Always read first when working in this repo | `.agents/skills/dotfiles-context/SKILL.md` |
| Editing `.nix` files or running `nix` / `home-manager` commands | `.agents/skills/nix-home-manager/SKILL.md` |
