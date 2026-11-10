# yomiyasu vendor record

- Upstream: https://github.com/nanaism/yomiyasu
- Commit: 552c12c472ddfb79e2ee7a15219847782686a945
- Version: 2.4.0
- Date: 2026-10-25
- License: MIT. See `LICENSE` and `UNICODE-LICENSE.txt`.
- Vendored under: `skills/yomiyasu/`

## Local changes

- The upstream `SKILL.md` is the base. The frontmatter is adapted for pi: `name`, `description`, `license`, `metadata.upstream`, `metadata.version`, and `disable-model-invocation: true`.
- The standalone `/yomiyasu` invocation paragraph is removed. `explain` owns the Japanese trigger; this skill is also available as `/skill:yomiyasu`.
- A note records that scripts and references are relative to this directory.
- Scripts and references are unchanged.
- Omitted: `assets/`, `.codex-plugin/`, and `scripts/yomiyasu_hook.py`.
