# File Change Reporting Rule

When an agent modifies files, it must present a change summary after all edits are complete and before any commit.

Do NOT show raw diffs in the chat output. The user can review diffs with `git diff` or `git log -p`. The agent's job is to interpret the changes, not to re-display them.

## Output format

1. **File table**: List every modified file with a one-line description of what changed. Use a Markdown table.
2. **Per logical change**: Group related file changes into a logical change section. For each logical change, provide:
   - **Rationale**: Why the change was made — what problem it solves or what feature it adds.
   - **Effect**: What the change does at runtime or build time. Mention any behavior that changes for the user.
   - **Risks**: Trade-offs, potential side effects, or edge cases. If there are no meaningful risks, write "None" and move on.

## Example

```markdown
### Changed files

| File | Change |
|------|--------|
| modules/packages.nix | + typescript package |
| modules/nvim.nix | + vim.g.tsserver_path setting |
| modules/nvim/lua/plugins/nvim-lspconfig.lua | + ts_ls cmd with --tsserver-path |

### Fix: ts_ls unable to find tsserver

Rationale:
  typescript-language-server requires the tsserver binary, but the
  typescript package was not installed.

Effect:
  TypeScript LSP starts without errors. Completion, go-to-definition,
  and hover now work for TS/JS files.

Risks:
  Global tsserver may differ from a project's local TypeScript version.
  IDE features are unaffected; compilation uses the project's own tsc.
```

If a turn makes only trivial changes (formatting, typos), a single-line
rationale per file in the table is sufficient — skip the per-change sections.
