# herdr vendor record

- Upstream: https://github.com/herdrdev/herdr (`skills/herdr/SKILL.md` and `LICENSE`)
- Pin: the `skill-herdr` input in the dotfiles `flake.lock`. `nix flake update` moves it.
- License: Apache-2.0. See `LICENSE`.
- Built by: `pi-skills/default.nix` in azzz9/dotfiles, from the pinned upstream plus
  `pi-skills/upstream/herdr/local.patch`.

## Local changes

The patch holds every change. In words:

- The frontmatter adds `license`, `metadata.upstream`, and `metadata.note` for pi.
- Omitted: the rest of the upstream repository.
