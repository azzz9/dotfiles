# pi-skills

The rules, the skills, and the extensions used on these machines, as a pi package. It used to be
the separate repository azzz9/skills. `default.nix` builds it into a store path, the `skills` row
in `modules/pi.nix` hands that path to pi, and `hosts/default.nix` links `AGENTS.md` and
`APPEND_SYSTEM.md` from it into `~/.pi/agent/`.

## Where it comes from

Parts of it come from [`cursor/plugins` pstack](https://github.com/cursor/plugins/tree/main/pstack). The
skills and several workflow ideas began as theirs, and plenty of the wording is still theirs. Thank you.
`LICENSE` keeps their copyright notice beside the modification notice.

## Skills

Five skills. One is ours and four follow their upstream projects.

- `workspace` lives in `skills/workspace/` and owns worktrees and Herdr workspaces.
- `herdr` from [`herdrdev/herdr`](https://github.com/herdrdev/herdr) (Apache-2.0).
- `imozuru` from [`MaryCache/imozuru`](https://github.com/MaryCache/imozuru) (MIT). Its scripts need
  Python 3.10+ and use only the standard library. Optional `pdftotext`, `yt-dlp`, `tesseract`, and
  `ax` improve PDF, YouTube, OCR, and HTML handling.
- `retro` from [`mattpocock/skills`](https://github.com/mattpocock/skills) (MIT).
- `yomiyasu` from [`nanaism/yomiyasu`](https://github.com/nanaism/yomiyasu) (MIT).

`retro` is hidden from the catalog and runs through `/skill:retro`.

## Upstream-tracked skills

The four upstream skills are not copied into this tree. For each one:

1. A `flake = false` input in `flake.nix` (`skill-herdr`, `skill-imozuru`, `skill-retro`,
   `skill-yomiyasu`) fetches the upstream repository. `flake.lock` pins the revision, and
   `nix flake update` (the daily pin bump) moves it.
2. `default.nix` copies the part of the upstream tree the skill uses into `skills/<name>/`.
3. It applies `upstream/<name>/local.patch` with `git apply`, when the skill has one. The patch
   is every local change: frontmatter for pi, adapted paragraphs, and local fixes. `yomiyasu`
   has no patch and ships as upstream wrote it.
4. It adds `upstream/<name>/VENDOR.md`, which says in words what the patch changes and what is
   left out.

When an upstream change breaks a patch, the build fails, and so does every check. Rebase the patch
onto the new upstream, keeping the local intent. To change a tracked skill, edit its patch: run
`nix build .#pi-skills`, copy `result/skills/<name>/` twice into a scratch directory, edit one
copy, and append `git diff --no-index` of the two (with the directory prefixes stripped) to the
patch, or regenerate it against a fresh upstream copy.

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

## Tests

`scripts/*.test.mjs` run against the built package in the `pi-skills` check
(`checks/default.nix`), so `scripts/check.sh`, the pre-push hook, and CI all run them. To run them
by hand: `nix build .#pi-skills && (cd result && node --test scripts/*.test.mjs)`.

## License

MIT. `LICENSE` keeps the upstream notice and the modification notice. Each upstream skill keeps
its upstream license beside it.
