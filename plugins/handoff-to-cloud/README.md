# handoff-to-cloud

Plan the work **locally**, where the context and the arguing happen. Then hand
the committed plan to a **Claude Code cloud session** that executes it
autonomously and opens a pull request. Nothing runs on the laptop, so it can be
closed.

What the skill does: confirm the plan is committed → push the branch → fire a
pre-configured cloud routine (`/fire` API) with a per-run prompt → return the
session URL.

## Install

```
/plugin marketplace add tomaass/tomaass-skills
/plugin install handoff-to-cloud@tomaass-skills
```

## What you have to set up yourself

Once per repository: a routine on claude.ai/code/routines with an API trigger,
and its token stored in `~/.claude/handoff-cloud.<repo>.env`. The steps are in
[SKILL.md](skills/handoff-to-cloud/SKILL.md#one-time-setup-per-repository).

## Limits worth knowing

- Routines belong to one account: every run appears as you and counts against
  your daily cap. For a team, the same handoff belongs in CI.
- The cloud environment has no database and restricted network by default, so
  the run must say which checks it could not perform.
