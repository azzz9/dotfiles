# Steps 10-11: Commit, Push, and Post-PR Review Loop

Once the human approves the diff, commit the changes using Conventional Commits:

```bash
git add <relevant files>
git commit -m "type(scope): subject"   # see conventional-commit skill
```

Use the `conventional-commit` skill for message format and staging rules. Do not push without explicit human confirmation.

After the human confirms, push:

```bash
git push
```

### 11. Post-PR Review Loop

Before creating the PR, ask the human for the base branch:

"What base branch should this PR target? (default: main)"

After the human confirms the base branch and grants permission, create the PR.

PR title format:
- With ticket: `<ticket_key> <ticket_title>` (half-width space separator)
  Example: `PROJ-123 Add rate limiter to search endpoint`
- Without ticket: Conventional Commits format `type(scope): subject`
  Example: `feat(middleware): add rate limiter to search endpoint`

Before writing the PR body, check for a PR template in the repository:

```bash
ls .github/PULL_REQUEST_TEMPLATE.md .github/pull_request_template.md    PULL_REQUEST_TEMPLATE.md pull_request_template.md 2>/dev/null
```

If found, use it as the base structure for the PR body.
If not found, use this default:

```markdown
## Summary
<what changed and why>

## Related ticket
<ticket key + title, or "N/A">

## Changes
- <change 1>
- <change 2>

## Test plan
- [ ] <how to verify change 1>
- [ ] <how to verify change 2>

## Breaking changes
<if any, describe impact and migration path; otherwise "None">

## Checklist
- [ ] Tests pass
- [ ] Lint passes
- [ ] Build succeeds
- [ ] Coverage did not decrease
```

```bash
gh pr create --base <base> --title "<title>" --body "<description>"
```

Then poll for review comments:

```bash
gh pr view --comments                              # check PR comments
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments   # inline review comments
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews   # review summaries
```

If actionable comments exist:

1. Create a follow-up fix prompt (same structure as the Fix-and-Reinspect Loop). Run validation (Step 7) after each fix.
2. Execute the fix by spawning a new implementation agent (same mechanism as Step 6).
3. Re-review with a separate review agent (same mechanism as Step 8).
4. Commit with Conventional Commits and capture the commit hash.
5. Reply to each addressed review comment via the GitHub API using the templates in [pr-reply-template.md](./references/pr-reply-template.md):

   ```bash
   gh api --method POST repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
     -f body="<reply body from pr-reply-template.md>"
   ```
6. Ask the human for permission to push, then push.
7. Re-poll for comments.

Continue until no actionable comments remain. The human does not participate in the fix-and-reinspect part of this loop, but every push requires explicit human permission.

When no comments remain, notify the human that the PR is merge-ready.
