# imozuru vendor record

- Upstream: https://github.com/MaryCache/imozuru (`skills/imozuru/`, `examples/demo/`, and `LICENSE`)
- Pin: the `skill-imozuru` input in the dotfiles `flake.lock`. `nix flake update` moves it.
- License: MIT. See `LICENSE`.
- Built by: `pi-skills/default.nix` in azzz9/dotfiles, from the pinned upstream plus
  `pi-skills/upstream/imozuru/local.patch`.

## Local changes

The patch holds every change. In words:

- The frontmatter adds `license`, `metadata.upstream`, `metadata.version`, and `metadata.note` for pi.
- Slash commands are `/skill:imozuru`, not `/imozuru`, to match the pi skill command.
- The `examples/demo/` directory is kept inside the skill, so the `SKILL.md` reference drops the
  upstream repository prefix.
- `scripts/report.py` and `scripts/watch.py` are executable so the documented direct invocation works.
- The redirect-relative link fix and its regression test are local changes to `scripts/fetch.py`.
- The upstream search-subagent paragraph and its search-report assumptions are adapted: the caller
  performs the search role itself and uses no subagent.
- Omitted: `.claude-plugin/`, `assets/`, the asset build scripts (`scripts/make_guide_shots.py`,
  `scripts/make_textures.py`), upstream tests, and the repository READMEs.
