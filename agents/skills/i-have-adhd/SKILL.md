---
name: i-have-adhd
description: 'Shape output for a reader with ADHD. Every formatting rule lives in AGENTS.md under "Output rules"; this skill says why they matter here. Invoke with /i-have-adhd; stays on until "stop adhd mode".'
disable-model-invocation: true
license: MIT
metadata:
  tags: "ADHD, Output Style, Productivity, Formatting"
  category: "productivity"
---

# i-have-adhd

The reader has ADHD. The rules that shape a reply live in one place, `AGENTS.md` under "Output
rules". This skill does not restate them. It says why each one matters for this reader, and how
the mode turns off.

## Persistence

These rules apply to every response for the rest of the session, not only this one. They do not
expire after a few turns and they do not lapse when the topic changes. If you are unsure whether
they still apply, they do.

Turn them off only when the reader says "stop adhd mode" or "normal mode". Confirm in one line,
then return to your default style.

## What ADHD changes about reading

Five facts explain why the output rules exist.

1. Working memory is small. Anything not on screen is forgotten. Do not ask the reader to "keep
   in mind X."
2. Knowing the answer is not doing the answer. The friction between "got it" and "done it" is
   where work dies.
3. Starting is the hardest step. The first action must be obvious, small, and doable now.
4. Time estimates feel uniform. "A bit of work" and "a few hours" register the same. Vague
   estimates fail.
5. Dopamine is scarce. Visible progress matters. Buried wins do not register.

## How the rules map to those facts

Read `AGENTS.md`, "Output rules", and follow it. The mapping below is the reason, not a second
set of rules.

- **Shape.** Conclusion first, then the reading order. A reply the reader has to hold in their
  head fails fact 1. One small diagram beats a description of a structure.
- **Sentences.** Short declaratives, no dash, plain words. Long sentences and project vocabulary
  spend working memory the task needs.
- **Cap lists at five.** The visible working set has to stay small. Group and rank; keep the
  rest internally.
- **One next action, restated state.** Facts 2 and 3. The reader must know what to do now and
  where they are, without scrolling back.
- **Concrete time estimates, visible wins.** Facts 4 and 5. "About 15 minutes" is actionable.
  "Login now works, try `/login`" registers as progress.
- **Suppress tangents, matter-of-fact errors.** A second problem competes with the first. An
  alarmed tone spends the attention the fix needs.
