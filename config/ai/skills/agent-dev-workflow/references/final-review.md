# Step 9: Final Human Review

Once the agent finds no blockers, launch Hunk for the human to review the diff in the TUI:

```bash
herdr status                                       # verify Herdr is available
herdr pane split --current --direction right --cwd . --focus
herdr pane run <pane_id> "hunk diff"
```

If Herdr is not running, ask the user to launch `hunk diff` in their terminal.

After the Hunk session is live, add summary comments explaining what was checked and why, so the human can verify efficiently. Write detailed comments with full context — the user should be able to understand the reasoning without asking follow-up questions.

Prefer `hunk session comment apply --repo . --stdin` with a JSON payload for all comments. This avoids shell quoting and truncation issues that occur with `--summary` / `--rationale` flags (shell expands `$`, `` ` ``, `!`, and `"` inside flag arguments, corrupting the comment text).

```bash
printf '%s\n' '{"comments":[{"filePath":"<file>","newLine":<line>,"summary":"<comment>","rationale":"<details>"}]}' | hunk session comment apply --repo . --stdin
```

Rules:
- In the JSON payload, use `\n` for line breaks. Do not embed raw newlines.
- `comment add` with `--summary` / `--rationale` is fine for short one-liners only.
- Avoid special shell characters in `--summary` without proper quoting. When in doubt, use the JSON batch form.

If the human finds issues:

1. Apply the fixes.
2. Re-enter the Fix-and-Reinspect Loop (fix → validate → separate review agent).
3. Ask for human review again when the agent finds no blockers.

The human may also choose to address warnings or info findings at this stage.
