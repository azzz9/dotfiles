# skills

The rules, the skills, and the agents used on this machine, as a pi package.

## Where it comes from

Parts of it come from [`cursor/plugins` pstack](https://github.com/cursor/plugins/tree/main/pstack). The
skills and several workflow ideas began as theirs, and plenty of the wording is still theirs. Thank you.
`LICENSE` keeps their copyright notice beside the modification notice.

`skills/herdr` and `skills/hunk-review` are vendored from their upstream projects. Each keeps
the upstream `LICENSE` beside it and a `metadata.upstream` note in its frontmatter.

`skills/yomiyasu` is vendored from [`nanaism/yomiyasu`](https://github.com/nanaism/yomiyasu)
(MIT). It keeps the upstream `LICENSE` and `UNICODE-LICENSE.txt`; `VENDOR.md` records the commit and the
local changes.

`skills/imozuru` is vendored from [`MaryCache/imozuru`](https://github.com/MaryCache/imozuru)
(MIT). It keeps the upstream `LICENSE`; `VENDOR.md` records the commit and local changes. Its
scripts need Python 3.10+ and use only the standard library. Optional `pdftotext`, `yt-dlp`,
`tesseract`, and `ax` improve PDF, YouTube, OCR, and HTML handling.

`skills/retro` is vendored from [`mattpocock/skills`](https://github.com/mattpocock/skills)
(MIT). It keeps the upstream `LICENSE`; `VENDOR.md` records the commit and local changes. `retro` is
hidden.

## Skills

Seven skills. Two are ours and five are vendored.

- `explain`, `workspace`
- `herdr`, `hunk-review`, `imozuru`, `retro`, `yomiyasu`

`retro` and `yomiyasu` are hidden from the catalog and run through `/skill:<name>`. `explain` is a
single procedure; `imozuru` is a research procedure with a watch mode; `workspace` has modes and
owns worktrees and Herdr workspaces.

## Subagents

pstack owns delegation: its `poteto-mode` skill decides when to fan out and which agent runs
where. The main session checks the findings and makes the fix, without asking the human to
confirm them.

## Clone a session into a pane

`/clone-pane` copies the current session into an adjacent Herdr pane, so a side question never enters the
main transcript. The clone runs `pi --fork <session file>` in the new pane. Pass `down` for a vertical
split. It needs `HERDR_ENV=1` and a saved session.

## Know when another session changed the worktree

`external-changes.ts` lists files changed outside this session at the start of each run. It compares
`git status` mtimes against the state after this session's last edit. A clone's edits are marked before
the model reads the files.

## Scope

Written for pi. Other harnesses are untested. The skills are plain `SKILL.md` files and the rules are
plain Markdown, so they may travel, but nothing here has been verified against another runner.

## Install

Two files load on every turn. [APPEND_SYSTEM.md](APPEND_SYSTEM.md) holds the gates, the skill
routing, and the reply rules. [AGENTS.md](AGENTS.md) holds the turn
gate, the language rule, and the git rules. Wire both into `~/.pi/agent/`, and add this repository as a
package row so pi finds the skills, the agents, and `/clone-pane`. Install `pstack` for the
`agent` tool and the subagent workflows.

## License

MIT. `LICENSE` keeps the upstream notice and the modification notice.
