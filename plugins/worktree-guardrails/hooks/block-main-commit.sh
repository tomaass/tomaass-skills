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
# The repository is the one the commit runs in: `git -C <dir> commit`, else the
# last literal `cd <dir>` before the commit, else the hook's cwd (the session's
# directory; the Bash shell starts there on every call). A run-time path
# (`cd $W`) cannot be read, so the cwd rule applies.
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD

# Only guard git commits (also `git -C <dir> commit`).
commit_re='git([[:space:]]+-C[[:space:]]+([^[:space:];&|]+))?[[:space:]]+commit([[:space:];&|]|$)'
[[ $cmd =~ $commit_re ]] || exit 0
c_dir=${BASH_REMATCH[2]}
before=${cmd%%"${BASH_REMATCH[0]}"*}
# Escape hatch: intentional main commit.
case "$cmd" in *"[hotfix]"*) exit 0 ;; esac
# Command explicitly operates inside a worktree tree.
case "$cmd" in *".claude/worktrees/"*) exit 0 ;; esac

# Last `cd <dir>` in the text before the commit.
cd_dir=
rest=$before
cd_re='(^|[;&|[:space:]])cd[[:space:]]+([^[:space:];&|]+)'
while [[ $rest =~ $cd_re ]]; do
  cd_dir=${BASH_REMATCH[2]}
  rest=${rest#*"${BASH_REMATCH[0]}"}
done

# A literal directory word (quotes stripped, ~ and $HOME expanded), resolved
# against <base>; empty when it is built at run time or does not exist.
literal_dir() {
  local d=$1 base=$2
  d=${d#[\"\']}; d=${d%[\"\']}
  case "$d" in '~'|'~/'*) d="$HOME${d#\~}" ;; '$HOME'|'$HOME/'*) d="$HOME${d#\$HOME}" ;; esac
  case "$d" in *'$'* | *'`'* | *'*'* | *'?'*) return ;; esac
  case "$d" in /*) ;; *) d="$base/$d" ;; esac
  [ -d "$d" ] && (cd "$d" && pwd -P)
}

dir=$cwd
if [ -n "$cd_dir" ]; then
  d=$(literal_dir "$cd_dir" "$cwd"); [ -n "$d" ] && dir=$d
fi
if [ -n "$c_dir" ]; then
  d=$(literal_dir "$c_dir" "$dir"); [ -n "$d" ] && dir=$d
fi

# Repo context of the directory the commit runs in.
gd=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)
[ -z "$gd" ] && exit 0                                    # not a git repo -> allow
# Opt-out, per repository or globally: git config worktree-guardrails.enabled false
[ "$(git -C "$dir" config --type=bool --get worktree-guardrails.enabled 2>/dev/null)" = false ] && exit 0
gc=$(cd "$dir" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)
[ "$gd" != "$gc" ] && exit 0                              # linked worktree -> allow
# Branch name: symbolic-ref works on an unborn HEAD (fresh repo, no commits yet),
# where `rev-parse --abbrev-ref HEAD` returns the literal string "HEAD" and makes
# this hook misfire. rev-parse stays as the fallback for a detached HEAD.
br=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
case "$br" in main | master) ;; *) exit 0 ;; esac        # primary but feature branch -> allow

echo "BLOCKED: this 'git commit' would land on the primary checkout's '$br' branch. Do feature work in a worktree (EnterWorktree, or 'git worktree add'), or add [hotfix] to the commit message for an intentional main commit." >&2
exit 2
