#!/usr/bin/env bash
# PreToolUse hook (matcher: Edit|Write|MultiEdit).
#
# Blocks edits made in the MAIN git checkout while on a non-default branch —
# i.e. the "I created a feature branch with `git checkout -b` in the primary
# working directory instead of an isolated worktree" mistake.
#
# ALLOWS: edits in a linked worktree (git-dir != git-common-dir), edits on the
# main/master branch, and files outside any git repo (e.g. ~/.claude, scratch).
#
# On block: exit 2 (PreToolUse blocking error) with a message on stderr telling
# the agent to create a worktree first (EnterWorktree or `git worktree add`).
f=$(jq -r '.tool_input.file_path // empty')
d=$(dirname "$f" 2>/dev/null); [ -d "$d" ] || d="$PWD"
gd=$(cd "$d" 2>/dev/null && git rev-parse --absolute-git-dir 2>/dev/null)
[ -z "$gd" ] && exit 0                      # not a git repo -> allow
gc=$(cd "$d" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)
[ "$gd" != "$gc" ] && exit 0                # linked worktree -> allow
# Branch name: symbolic-ref works on an unborn HEAD (fresh repo, no commits yet),
# where `rev-parse --abbrev-ref HEAD` returns the literal string "HEAD" and makes
# this hook misfire. rev-parse stays as the fallback for a detached HEAD.
br=$(cd "$d" && { git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null; })
case "$br" in main|master) exit 0;; esac    # default branch -> allow
echo "BLOCKED: '$f' is being edited on branch '$br' in the MAIN checkout. Feature work must happen in an isolated worktree — create one first (EnterWorktree, or 'git worktree add'), then edit there." >&2
exit 2
