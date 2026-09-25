# review-loop

A bounded review → fix → re-review loop over one pull request. It decides after
every round whether another round is worth it — and usually it is not.

## Why not "loop until no findings"

Because it does not converge. Three real pull requests, findings per round:

| PR | round 1 | round 2 | round 3 |
|---|---|---|---|
| #78 | 7 | 9 (4 caused by round 1's fix) | — |
| #82 | 10 | 10 (4 caused by round 1's fix) | — |
| #80 | 7 | 8 (round 1's fix made the main symptom **worse**) | 10 (two earlier defects back) |

Fix commits generate findings at roughly the rate the original code did. So
the loop's job is to notice early which failure is happening, and stop:

- a defect you already fixed is back → stop, on the first occurrence;
- two findings caused by the last round's fix → narrow or delete, don't fix again;
- the same root cause two rounds in a row → name the model that is wrong,
  extract it to its own ticket, ship the narrow fix.

Every stop rule carries the incident that produced it — see
[SKILL.md](skills/review-loop/SKILL.md).

## Install

```
/plugin marketplace add tomaass/tomaass-skills
/plugin install review-loop@tomaass-skills
```

Then `/review-loop <PR#> [max-rounds]` (default 3). It never merges.

## What you have to set up yourself

- **Gates** — the command that must be green before and after each round. Set
  it in the plugin options, or name your build and test commands in the
  repository's `CLAUDE.md`. Without gates the loop reports green while proving
  nothing, so it asks instead of guessing.
- **Review command** — defaults to `/code-review`.

## Where it runs

Locally, on purpose: the reviewer should be a session that did not write the
code. It pairs with [handoff-to-cloud](../handoff-to-cloud) — the cloud writes
and opens the PR, a local session reviews it. Running the review inside the
cloud run is an open gap, not a solved one: that environment has no browser,
so it could not verify what it would be asked to.
