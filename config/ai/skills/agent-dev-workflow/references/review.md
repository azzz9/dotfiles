# Steps 7-8: Validate, Review, and Fix-and-Reinspect Loop

After the implementation agent completes, run validation before sending the diff to a review agent. The Main Agent runs these checks:

- **Tests**: run the project's test suite. Any test that was passing in the Step 3 baseline but now fails is a regression.
- **Coverage**: run the project's coverage tool. Report before and after as concrete numbers:
  - Baseline: <XX.X%>  After: <YY.Y%>  Delta: <+/-Z.Z%>
  - Coverage must not decrease. If it decreases, treat as a regression and re-enter the Fix-and-Reinspect Loop.
  - If no coverage tool is configured, state "No coverage tool configured" explicitly — do not skip silently.
- **New tests**: verify that tests exist for the new behavior introduced by this change. If no tests were added, flag this as a finding for the review agent.
- **Lint / typecheck**: run the project's linter and type checker. New warnings compared to the Step 3 baseline must be caused by the implementation.
- **Format**: run the project's formatter in check mode. New violations compared to the Step 3 baseline must be caused by the implementation. If no formatter is configured, skip silently.
- **Build**: run the project's build command. If the Step 3 baseline already had build failures, only new failures count.
- **Diff scope**: verify with both `git status --short` and `git diff --stat` that changes are within the intended scope. `git diff --stat` does not show untracked files, so use `git status --short` to catch new tests, generated files, or accidental artifacts.

If any check fails, re-enter the Fix-and-Reinspect Loop with the failure output as the fix prompt. Do not proceed to review until all checks pass.

### 8. Review with a Separate Agent

Spawn a separate agent for review to avoid confirmation bias. The review agent must not carry the investigation or implementation context.

Use whichever mechanism is available in your environment:

- **Codex built-in review**: `codex exec review --uncommitted --ephemeral -o review.txt`
- **Codex prompt-driven review**: `codex exec --ephemeral --sandbox read-only -o review.txt "Review the uncommitted changes. Focus on acceptance criteria coverage and behavioral regressions. Classify findings as Blocker, Warning, or Info."`
- **Copilot CLI**: `copilot -p '/review the changes on this branch. Focus on bugs and security issues.' -s --allow-tool='shell(git:*)' --no-ask-user`
- **Manual**: output a review prompt for the user to paste into a fresh agent session.

Use the prompt-driven Codex form when you need custom classification instructions. Some Codex CLI versions do not accept a custom prompt together with `codex exec review --uncommitted`.

The review agent should classify findings as:

- **Blocker**: must be fixed before proceeding (bugs, security, regressions, scope violations, missing tests for critical behavior).
- **Warning**: should be fixed if time permits, but can be ignored (style, minor naming, optional improvements).
- **Info**: informational notes, no action required.

If no blockers are found, proceed to Final Human Review. The human can decide whether to address warnings or info.

### Fix-and-Reinspect Loop

Turn review findings into a focused repair prompt. The prompt should:

- Reference the original ticket key or implementation prompt.
- List only concrete required fixes.
- Distinguish blockers from optional cleanup.
- Tell the coding agent to inspect the existing diff before editing.
- Require rerunning relevant validation.
- Forbid unrelated refactors unless the user explicitly asks for them.

Execute the fix by spawning a new implementation agent (same mechanism as Step 6). Do not fix in the Main Agent context -- it carries investigation bias. The fix prompt is self-contained and includes the current diff context, so the implementation agent does not need prior session history.

After the fix, re-review with a separate review agent (same mechanism as Step 8). Do not fall back to `git diff` in the Main Agent -- every iteration must use a separate review agent to maintain context separation.

The fix loop only addresses blockers. Warnings and info findings are acknowledged but do not block progression. When no blockers remain, proceed to Final Human Review.

Loop guard: if the fix-and-reinspect loop runs more than 3 iterations without converging on blockers, stop and escalate to the human with a summary of persistent findings. Do not loop indefinitely.

Only stop for human input before the guard limit when a blocker requires a product or design decision rather than a straightforward code correction.
