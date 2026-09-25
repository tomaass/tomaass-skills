---
name: review-loop
description: Run a bounded review → fix → re-review loop over one pull request, deciding after each round whether another round is worth it. Use when the user asks to review-and-fix a PR until it is ready, when a review round has come back and the question is whether to fix and re-review or stop, or when a defect reappears mid-loop; also on /review-loop. Caps the rounds, stops on the signals that mean iterating will not help, and never merges.
---

# Review loop over one PR

Runs the project's code review against one pull request, reports the findings,
fixes what should be fixed, and re-reviews — for at most a few rounds, stopping
as soon as another round stops being the useful move.

**Invoke:** `/review-loop <PR#> [max-rounds]` — default 3.

## Why this is not "loop until no findings"

That does not converge, and the sessions that produced this skill are the
evidence. Three pull requests from a production repository, findings per round:

| PR | round 1 | round 2 | round 3 |
|---|---|---|---|
| #78 | 7 | 9 (4 caused by round 1's fix) | — |
| #82 | 10 | 10 (4 caused by round 1's fix) | — |
| #80 | 7 | 8 (round 1's fix made the main symptom **worse**) | 10 (two earlier defects back, from new directions) |

Fix commits generate findings at roughly the rate the original code did. A loop
that runs until the count hits zero would burn every round and still land
somewhere arbitrary. On #82 the right answer at round 2 was to **delete** the
machinery the fixes kept defending; on #80 it was to **fix the state model**
rather than its symptoms a third time. Neither is reachable by iterating.

So the loop's job is not to exhaust findings. It is to notice, early, which of
these is happening — and stop.

## Configure this per repository

The stop rules below transfer unchanged. These three things do not, so read
them before the first round:

| What | Where it comes from |
|---|---|
| **Gate command** — what must be green before and after every round | `$CLAUDE_PLUGIN_OPTION_REVIEW_GATES` if set, otherwise the build and test commands named in the repository's `CLAUDE.md` |
| **Review command** — how this project runs a code review | `$CLAUDE_PLUGIN_OPTION_REVIEW_COMMAND` if set, otherwise `/code-review` |
| **Worktree location** — where PR heads get checked out | the project's own convention, otherwise `.claude/worktrees/pr-<N>` |

If a repository has none of these, say so and ask rather than guessing. A loop
that runs the wrong gates reports green while proving nothing.

## Per round

1. **Set up** a worktree for the PR head if there is not one already:
   `git fetch origin refs/pull/<N>/head:pr-<N> -f && git worktree add <worktree>/pr-<N> pr-<N>`.
   Copy across whatever local environment files the project needs and install
   dependencies. Invoke tool binaries directly rather than through package
   scripts — script wrappers frequently fail in a fresh worktree for reasons
   unrelated to the code under review.
2. **Run the gates yourself** before reviewing, so the review's own claims can
   be checked against known facts.
3. **Dispatch** the review, handing it the full brief — see *What to hand the
   reviewer*.
4. **Report** the findings once, most severe first. Never also print them as
   prose.
5. **Decide** with the stop rules below. If stopping, say which rule fired and
   why.
6. **Fix**, re-run the gates, commit, push, verify `remote tip == local tip`,
   and report again with an outcome on every finding.

## Stop rules, in priority order

Check them in this order and take the first that fires.

1. **A finding needs a product decision** → stop and ask. Copy, hierarchy, how
   much to warn about — not yours to settle. Present the options with what each
   costs.
2. **A defect you already fixed in an earlier round is back** → stop
   immediately, on the first occurrence. Not "two of them", not "next round" —
   one is enough. It means the fix is being defended rather than the problem
   solved, and the next attempt will re-break something else. On #80 this was
   missed: round three reintroduced round two's no-op regression on a different
   code path *and* round one's mislabelled-price defect via a timestamp instead
   of a value, and the loop ran a whole extra round before anyone noticed.
3. **Two or more findings this round were caused by the previous round's fix**
   → stop. The fixes are generating more than they close. Propose **narrowing
   or deleting** rather than another attempt. On #82 this meant dropping three
   pieces of machinery and keeping only the guard — the residual PR was correct
   and smaller.
4. **The same root cause appears in two consecutive rounds** → stop. Symptoms
   are being patched, so name the underlying model and propose changing it. On
   #80 one flag meant both "the feed is down" and "this number is carried over".

   Naming it is not the same as fixing it inside the PR. Splitting that flag
   *was* right, and it still produced ten new findings, because a model change
   inside a bugfix carries the bug's deadline and none of its own review. Name
   it, extract it to its own ticket with everything the rounds taught you, and
   ship the narrow fix.
5. **No confirmed correctness findings remain** → stop. Cleanup-only findings
   go to a follow-up issue, not into this PR. Hand it to the user for merge.
6. **Round cap reached** → stop and list precisely what is still open, with a
   recommendation per item.

If none fire, run another round.

## After the run, before moving on

Two checks and one question. They cost a minute and each of them exists because
skipping it cost more.

- **Check the worktree is clean.** Verifier subagents experiment on the real
  files — in one run three of them stripped a guard out of three separate
  modules to find out whether any test would notice. That is legitimate
  verification, but it means `git status` before you start fixing, or you build
  on top of someone else's half-reverted experiment.
- **Re-check your own suspects against the diff.** In one run the reviewer was
  told a config file with placeholder values had been committed by the PR;
  `git diff origin/main HEAD -- <path>` was empty, because the package manager
  had written it locally during install. A wrong suspect spends reviewer
  attention and lands in the findings as if it were the PR's.
- **Ask whether the loop itself should change.** Every run so far has produced
  one rule worth writing down, and the rules are what makes this better than
  "review again". Add it while the evidence is concrete — a rule with the
  incident attached is followed; a generic maxim is not.

## Disciplines that are not optional

- **A new test must be shown to fail against the old behaviour.** Revert the
  fix, run the test, watch it fail, restore. Twice in one session a test that
  looked like coverage asserted nothing — one restated a one-line predicate
  against itself, another asserted a constant was between 0 and 10000.
- **Never merge.** The loop ends with a recommendation; merging is the user's
  call.
- **Report every round through the structured findings tool**, including the
  follow-up call with outcomes after fixes land. Prose summaries do not update
  the per-finding status.
- **Own the ones you caused.** When a finding traces to your own previous fix,
  say so plainly in the summary. It is the signal rules 2 and 3 depend on, and
  hiding it breaks the loop's own logic.
- **Anything the reviewer cannot verify, verify yourself or say it is
  unverified.** No browser means no visual claim; a node-environment test suite
  cannot render components, so anything left in JSX is untestable by
  construction.

## What to hand the reviewer

The brief carries the whole context. Include:

- **Target**: PR number, worktree path, branch, tip commit, and who wrote each
  commit — a cloud session with no browser cannot have verified anything at
  runtime, and the reviewer should weigh its claims accordingly.
- **The bug in operational terms**, not just the diff: what the user does, what
  they see, what goes wrong. Reviews that got this were sharply better than
  reviews that got a file list.
- **What you already checked**, so the reviewer spends its budget elsewhere.

## Related

- Not every PR deserves this loop. Decide review depth first; a one-line
  config change needs one review, not three rounds.
- Pairs with `handoff-to-cloud`: when the cloud session opens its PR, run this
  loop locally, in a session that did not write the code.
