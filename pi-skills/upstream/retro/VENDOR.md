# retro vendor record

- Upstream: https://github.com/mattpocock/skills (`skills/engineering/retro/SKILL.md` and `LICENSE`)
- Pin: the `skill-retro` input in the dotfiles `flake.lock`. `nix flake update` moves it.
- License: MIT. See `LICENSE`.
- Built by: `pi-skills/default.nix` in azzz9/dotfiles, from the pinned upstream plus
  `pi-skills/upstream/retro/local.patch`.

## Local changes

The patch holds every change. In words:

- Frontmatter adds `license`, `metadata.upstream`, `metadata.version`, and `metadata.note` for pi.
- The `writing-for-agents` dependency is replaced with the repo's Output rules and `/skill:yomiyasu` for Japanese.
- `CLAUDE.md` references are reduced to `AGENTS.md`; `CODING_STANDARDS.md` is treated as optional.
- Omitted: `agents/openai.yaml` (plugin interface, not a pi-subagents agent).
