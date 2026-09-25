#!/usr/bin/env bash
# End-to-end tests for both PreToolUse guardrails.
#
# Builds a throwaway git repo, drives the hooks with the same JSON payload
# Claude Code sends them, and asserts the exit code. Exit 2 means "block the
# tool call", exit 0 means "allow".
#
# Run:  ./hooks/test-hooks.sh
set -uo pipefail

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0

# check <expected-exit> <description> <hook> <json-payload> [cwd]
check() {
  local want="$1" desc="$2" hook="$3" payload="$4" dir="${5:-$PWD}"
  local got
  printf '%s' "$payload" | (cd "$dir" && bash "$HOOKS/$hook" >/dev/null 2>&1)
  got=$?
  if [ "$got" = "$want" ]; then
    printf '  \033[32mok\033[0m   %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf '  \033[31mFAIL\033[0m %s — wanted exit %s, got %s\n' "$desc" "$want" "$got"
    fail=$((fail + 1))
  fi
}

edit_payload() { printf '{"tool_input":{"file_path":"%s"}}' "$1"; }
bash_payload() { printf '{"tool_input":{"command":"%s"}}' "$1"; }

# --- fixture: a repo with one commit, plus a linked worktree ------------------
REPO="$TMP/repo"
mkdir -p "$REPO" && cd "$REPO"
git init -q -b main
git config user.email t@example.com && git config user.name Test
echo hello > file.txt && git add -A && git -c commit.gpgsign=false commit -qm init
git worktree add -q "$TMP/wt" -b feature-in-worktree
echo "  (fixture: $REPO)"

echo
echo "require-worktree.sh — blocks writes in the primary checkout on a feature branch"
git -C "$REPO" checkout -q main
check 0 "primary checkout, on main"                 require-worktree.sh "$(edit_payload "$REPO/file.txt")" "$REPO"
git -C "$REPO" checkout -q -b feature-in-primary
check 2 "primary checkout, on a feature branch"     require-worktree.sh "$(edit_payload "$REPO/file.txt")" "$REPO"
check 0 "linked worktree, on a feature branch"      require-worktree.sh "$(edit_payload "$TMP/wt/file.txt")" "$TMP/wt"
check 0 "path outside any git repo"                 require-worktree.sh "$(edit_payload "$TMP/loose.txt")" "$TMP"

echo
echo "block-main-commit.sh — blocks commits landing on the primary checkout's main"
git -C "$REPO" checkout -q main
check 2 "commit on main in the primary checkout"    block-main-commit.sh "$(bash_payload "git commit -m x")"          "$REPO"
check 0 "same commit carrying the [hotfix] marker"  block-main-commit.sh "$(bash_payload "git commit -m \\\"[hotfix] x\\\"")" "$REPO"
git -C "$REPO" checkout -q feature-in-primary
check 0 "commit on a feature branch"                block-main-commit.sh "$(bash_payload "git commit -m x")"          "$REPO"
check 0 "commit inside a linked worktree"           block-main-commit.sh "$(bash_payload "git commit -m x")"          "$TMP/wt"
check 0 "a command that is not a commit at all"     block-main-commit.sh "$(bash_payload "ls -la")"                   "$REPO"

echo
echo "regression — unborn HEAD (a repo with no commits yet)"
echo "  rev-parse --abbrev-ref HEAD returns the string \"HEAD\" here, which made"
echo "  one hook fail open and the other fail closed."
FRESH="$TMP/fresh"; mkdir -p "$FRESH" && (cd "$FRESH" && git init -q -b main)
check 2 "first commit to main is still blocked"     block-main-commit.sh "$(bash_payload "git commit -m x")"  "$FRESH"
check 0 "editing is still allowed"                  require-worktree.sh "$(edit_payload "$FRESH/new.txt")"    "$FRESH"

echo
if [ "$fail" -eq 0 ]; then
  printf '\033[32m%s passed, 0 failed\033[0m\n' "$pass"
else
  printf '\033[31m%s passed, %s FAILED\033[0m\n' "$pass" "$fail"
fi
exit $((fail > 0))
