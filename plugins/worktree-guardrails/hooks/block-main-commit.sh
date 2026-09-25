#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash).
#
# Blocks a `git commit` that would land on the PRIMARY checkout's main/master
# branch — the "a subagent accidentally committed to main in the primary
# checkout" failure. Feature work commits in a linked worktree; hotfixes on main
# are allowed explicitly by putting [hotfix] in the commit message.
#
# ALLOWS: non-commit commands, commits in a linked worktree (git-dir !=
# git-common-dir), commits when the primary checkout is on a feature branch,
# commands that target a worktree path, and any commit whose message carries the
# [hotfix] escape marker.
#
# Uses THIS hook's own cwd git-context (same approach as require-worktree.sh),
# which matches the command's cwd.
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only guard git commits.
case "$cmd" in *"git commit"*) ;; *) exit 0 ;; esac
# Escape hatch: intentional main commit.
case "$cmd" in *"[hotfix]"*) exit 0 ;; esac
# Command explicitly operates inside a worktree tree.
case "$cmd" in *".claude/worktrees/"*) exit 0 ;; esac

# Repo context of the hook's cwd (== the command's cwd).
gd=$(git rev-parse --absolute-git-dir 2>/dev/null)
[ -z "$gd" ] && exit 0                                    # not a git repo -> allow
gc=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)
[ "$gd" != "$gc" ] && exit 0                              # linked worktree -> allow
# Branch name: symbolic-ref works on an unborn HEAD (fresh repo, no commits yet),
# where `rev-parse --abbrev-ref HEAD` returns the literal string "HEAD" and makes
# this hook misfire. rev-parse stays as the fallback for a detached HEAD.
br=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
case "$br" in main | master) ;; *) exit 0 ;; esac        # primary but feature branch -> allow

echo "BLOCKED: this 'git commit' would land on the primary checkout's '$br' branch. Do feature work in a worktree (EnterWorktree, or 'git worktree add'), or add [hotfix] to the commit message for an intentional main commit." >&2
exit 2
