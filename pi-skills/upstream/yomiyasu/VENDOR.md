# yomiyasu vendor record

- Upstream: https://github.com/nanaism/yomiyasu (`skills/yomiyasu/`)
- Pin: the `skill-yomiyasu` input in the dotfiles `flake.lock`. `nix flake update` moves it.
- License: MIT. See `LICENSE` and `UNICODE-LICENSE.txt`.
- Built by: `pi-skills/default.nix` in azzz9/dotfiles, from the pinned upstream plus
  `pi-skills/upstream/yomiyasu/local.patch`.

## Local changes

The patch holds every change. In words:

- The upstream `SKILL.md` is the base. The frontmatter is adapted for pi: `description`,
  `metadata.upstream`, `metadata.note`, and `disable-model-invocation: true`.
- The standalone `/yomiyasu` invocation paragraph is replaced by a note that this skill runs as
  `/skill:yomiyasu` and that scripts and references are relative to this directory.
- Scripts and references are unchanged.
- Omitted: `assets/`, `.codex-plugin/`, and `scripts/yomiyasu_hook.py`.
