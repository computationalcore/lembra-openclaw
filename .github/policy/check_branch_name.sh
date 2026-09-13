#!/usr/bin/env bash
# Enforces the gitflow-branches skill.
# usage: check_branch_name.sh "<branch>"   exit 0 = ok, 1 = reject (reason on stderr)
set -u
b="${1-}"
fail() { echo "branch-name: $1" >&2; echo "  branch: $b" >&2; exit 1; }
[ -n "$b" ] || fail "empty"
case "$b" in main|develop) exit 0 ;; esac
type="${b%%/*}"; rest="${b#*/}"
[ "$type" != "$b" ] || fail "must be '<type>/<semantic-name>'"
case "$type" in
  release) printf '%s' "$rest" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$' || fail "release branches are 'release/<semver>'"; exit 0 ;;
  support) printf '%s' "$rest" | grep -Eq '^[0-9]+\.(x|[0-9]+)$' || fail "support branches are 'support/1.x' or 'support/2.3'"; exit 0 ;;
  feature|bugfix|hotfix|refactor|perf|docs|test|build|ci|chore) ;;
  fix) fail "use 'bugfix/' (or 'hotfix/' for emergency production remediation), not 'fix/'" ;;
  *) fail "unknown type '$type'" ;;
esac
# optional ticket segment: TYPE/ABC-123/name
if printf '%s' "$rest" | grep -Eq '^[A-Z][A-Z0-9]+-[0-9]+/'; then rest="${rest#*/}"; fi
printf '%s' "$rest" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || fail "name must be lower-case kebab-case (no underscores, camelCase, spaces, or extra slashes)"
words=$(printf '%s' "$rest" | awk -F- '{print NF}')
[ "$words" -ge 2 ] || fail "name needs at least two words that state the objective"
[ "$words" -le 6 ] || fail "name has $words words; compress to 2-5 without losing the distinction"
printf '%s' "$rest" | grep -Eq -- '(^|-)(v[0-9]+|final|new|old|working|ready|wip|tmp|temp|test|draft)$' && fail "must not encode workflow state ('$rest')"
printf '%s' "$rest" | grep -Eq -- '(^|-)(changes|update|updates|fixes|misc|cleanup|stuff|new-version)$' && fail "generic name says nothing ('$rest')"
printf '%s' "$rest" | grep -Eq -- '-and-' && fail "one branch, one intent (split on 'and')"
printf '%s' "$rest" | grep -Eq -- '(^|-)[a-z]+\.(ts|tsx|js|py|rs|go|swift|kt|sql|md)(-|$)' && fail "must not name a file"
exit 0
