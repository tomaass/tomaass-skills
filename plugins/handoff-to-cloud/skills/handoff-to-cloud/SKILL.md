---
name: handoff-to-cloud
description: Hand off a finished implementation plan from this local session to a Claude Code cloud session for autonomous execution. Use when the user wants to "run it in the cloud", "hand off to cloud", "let the cloud finish the plan", or invokes /handoff-to-cloud after a plan has been written. Pushes the current branch and fires a pre-configured cloud routine via its /fire API.
---

# Hand off a plan to the cloud

The workflow this supports: brainstorm and write the plan **locally**, where the
context and the arguing happen, then let a **Claude Code cloud session** execute
it autonomously while the laptop is closed.

This skill automates the handoff: confirm the plan is committed → push the
branch → fire a pre-configured cloud routine with a per-run prompt → return the
session URL.

## Why a routine and not a deep link

The routine's `/fire` endpoint is the supported way to start a cloud session
programmatically with a custom prompt. It is also the reason this is a skill
rather than a habit: the handoff has preconditions — the plan committed, the
branch pushed — that are exactly what a human skips at 18:00.

## One-time setup, per repository

**One routine clones one repository.** Adding a second repository to an existing
routine does not let `/fire` target it: the session still clones the routine's
primary repository and the branch will not be found. So every repository needs
its own routine, and its credentials live in a repository-specific env file.

If `~/.claude/handoff-cloud.<repo>.env` does not exist, tell the user to do this
first — do **not** attempt it for them. The token is shown once on the web and
the CLI cannot generate it.

1. Go to **claude.ai/code/routines** → **New routine**.
2. **Prompt** (saved and generic; the per-run detail arrives in the fire text):
   > You are executing a committed implementation plan in this repository.
   > Follow the per-run instructions provided in the routine-fire-payload
   > exactly. Prefer the repository's committed skills. Work autonomously; do
   > not merge anything.

   The saved prompt must reference the payload explicitly. Fire text arrives
   wrapped and labelled as untrusted data, so a prompt that does not opt in
   treats it as inert context.
3. **Repositories:** add only this one.
4. **Permissions:** enable unrestricted branch pushes, so it pushes back to the
   feature branch rather than a `claude/` branch.
5. **Environment:** the default environment has *Trusted* network access, which
   allows only the default allowlist. If the run must reach your own services —
   a preview deployment, an internal API — add those domains first.
6. **Trigger:** add an **API** trigger, generate the token (copy it now, it is
   shown once), and copy the fire URL.
7. Store both outside the repository:

```bash
cat > ~/.claude/handoff-cloud.<repo>.env <<'EOF'
CC_ROUTINE_FIRE_URL="https://api.anthropic.com/v1/claude_code/routines/trig_XXXX/fire"
CC_ROUTINE_TOKEN="sk-ant-oat01-XXXX"
EOF
chmod 600 ~/.claude/handoff-cloud.<repo>.env
```

## Running the handoff

1. **Resolve the plan.** Use the path the user passed. If none, pick the newest
   plan file in the project's plans directory and state which one you chose.
2. **Resolve the branch.** If it is the default branch, stop and ask the user to
   switch — the cloud run pushes to this branch.
3. **Check the plan is committed.** The cloud session clones from the remote, so
   anything uncommitted will not be seen. Offer to commit it.
4. **Confirm before firing.** This starts a billed, autonomous run and pushes a
   branch. Show the branch, the plan path, and what will happen. Wait for an
   explicit yes.
5. **Push and fire.**

```bash
set -euo pipefail
source ~/.claude/handoff-cloud."$REPO".env
: "${CC_ROUTINE_FIRE_URL:?run the one-time setup}"
: "${CC_ROUTINE_TOKEN:?run the one-time setup}"

BRANCH="$(git symbolic-ref --quiet --short HEAD)"
git push -u origin "$BRANCH"

TEXT="Execute the implementation plan in this repository, autonomously.

1. git fetch origin && git checkout ${BRANCH}
2. Read the plan at ${PLAN}
3. Execute it task by task, committing after each task as the plan specifies.
4. Verification: run the gates that work in this environment. State plainly in
   the pull request which checks could not run here and must be run locally.
5. When the gates are green, push ${BRANCH} and open a pull request. Do NOT merge."

RESP="$(curl -sS -X POST "$CC_ROUTINE_FIRE_URL" \
  -H "Authorization: Bearer ${CC_ROUTINE_TOKEN}" \
  -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg t "$TEXT" '{text:$t}')")"

printf '%s\n' "$RESP" | jq -r '.claude_code_session_url // "no session URL — check the error above"'
```

6. **Report** the session URL. The run is autonomous from here; the user
   monitors and approves the resulting pull request.

## Know the environment's limits before you write the prompt

The cloud environment is not your laptop, and the per-run prompt has to say so
explicitly or the run will report green on checks it never performed.

- **No database** unless the environment provides one, so database-backed test
  suites and end-to-end specs cannot run there. Tell the run to implement and
  commit the code anyway and to name, in the pull request, which verification is
  outstanding.
- **Restricted network** on the default environment.
- **Push rejected** if the branch is protected, carries someone else's commits,
  or has another person's open pull request.

## Failure modes

| Symptom | Cause |
|---|---|
| Error about the beta header | The dated `anthropic-beta` version has rolled; check the current sample on the routines page. |
| "Branch or plan does not exist" in the cloud, though it is on the remote | The routine is cloning a different repository. One routine, one repository. |
| Fire rejected | Daily routine run cap, or the subscription usage limit. |
| Pushes to a `claude/` branch | Unrestricted branch pushes is off in the routine's permissions. |

## Related

- **Routines belong to an individual account.** Everything a run does appears as
  that person. For a team, the same handoff has to move to CI running under the
  repository's identity.
