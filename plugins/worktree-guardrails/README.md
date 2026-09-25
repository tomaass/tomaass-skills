# worktree-guardrails

Two `PreToolUse` hooks for the two mistakes coding agents make with git most
often:

- **`require-worktree.sh`** (`Edit|Write|MultiEdit`) blocks an edit in the
  primary checkout while it is on a feature branch — the agent ran
  `git checkout -b` where it should have created a worktree.
- **`block-main-commit.sh`** (`Bash`) blocks a `git commit` that would land on
  `main`/`master` in the primary checkout — a subagent committing straight to
  main.

Both exit `2` with the reason on stderr, so the agent reads why and corrects
itself. Dependencies: `bash`, `git`, `jq`.

## Install

```
/plugin marketplace add tomaass/tomaass-skills
/plugin install worktree-guardrails@tomaass-skills
```

## Choose where it runs

On by default in every repository. Switch it with plain `git config`, so the
choice lives next to the repository and needs no list of paths:

```bash
# Only in the repositories where you run several agents at once:
git config --global worktree-guardrails.enabled false   # once: off everywhere
git config worktree-guardrails.enabled true             # in each big repo: back on

# Or the other way round — on everywhere, off in one repository:
git config worktree-guardrails.enabled false
```

The repository setting wins over the global one, as git config always does.
This is a guard against mistakes, not a security boundary: an agent that runs
`git config` itself can switch it off.

## Contract

| | `require-worktree.sh` | `block-main-commit.sh` |
|---|---|---|
| Blocks | write to the primary checkout while on a non-default branch | `git commit` landing on the primary checkout's `main`/`master` |
| Always allows | repos with `worktree-guardrails.enabled=false`; linked worktrees; the default branch; paths outside any git repo | repos with `worktree-guardrails.enabled=false`; non-commit commands; linked worktrees; feature branches; commands targeting `.claude/worktrees/` |
| Escape hatch | — | put `[hotfix]` in the commit message |

**Fails open on purpose.** If the path is not in a git repo, or git context
cannot be resolved, the hook allows. A guardrail that blocks work it does not
understand gets switched off within a week.

## Tests

```bash
./hooks/test-hooks.sh
```

Builds a throwaway repo with a linked worktree, drives both hooks with the same
JSON payload Claude Code sends, and asserts the exit code across sixteen cases, including the opt-out in both
directions.

Two of them are regression cases for a real bug: on a fresh repo with no
commits, `git rev-parse --abbrev-ref HEAD` returns the literal string `HEAD`,
which made one hook fail open and the other fail closed — from the same root
cause. Both tests were shown to fail against the old code before the fix was
kept; a test that has never failed proves nothing.
