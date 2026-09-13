#!/usr/bin/env bash
# Enforces the gitflow-branches skill.
# usage: check_branch_name.sh "<branch>"   exit 0 = ok, 1 = reject (reason on stderr)
set -u
# Length cap from the gitflow-branches skill ("roughly 2-5 semantic words") with one word of slack.
# No minimum: chore/deps is a legitimate branch; vagueness is the generic-name list's job, not a counter's.
MAX_WORDS=${MAX_WORDS:-6}
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
# Shape: GITFLOW_CLASS/ID-DESCRIPTION. The ticket id, when present, is always first and is
# recognised ONLY by the tracker's team keys (TICKET_KEYS, lower case, space-separated). Anything
# else after the type is the description. The old id shapes are rejected with the reason.
keys="${TICKET_KEYS:-vin lem}"
keyalt=$(printf '%s' "$keys" | tr 'A-Z' 'a-z' | tr -s ' ' '|')
keyALT=$(printf '%s' "$keyalt" | tr 'a-z' 'A-Z')
printf '%s' "$rest" | grep -Eq "^($keyalt|$keyALT)-[0-9]+/" \
  && fail "the ticket id is not its own segment: a slash is a directory in the ref namespace; write '$type/rea-92-<description>'"
printf '%s' "$rest" | grep -Eq "^($keyALT)-[0-9]+(-|$)" \
  && fail "the ticket id must be lower case ('$(printf '%s' "$rest" | cut -d- -f1,2 | tr 'A-Z' 'a-z')'): a case-insensitive filesystem cannot hold both cases of a ref"
printf '%s' "$rest" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || fail "name must be lower-case kebab-case (no underscores, camelCase, spaces, or extra slashes)"
printf '%s' "$rest" | grep -Eq "^($keyalt)-[0-9]+$" && fail "a ticket id alone is not a name; add the description: '${rest}-<description>'"
slug=$(printf '%s' "$rest" | sed -E "s/^($keyalt)-[0-9]+-//")
words=$(printf '%s' "$slug" | awk -F- '{print NF}')
[ "$words" -le "$MAX_WORDS" ] || fail "description has $words words; compress to at most $MAX_WORDS without losing the distinction"
printf '%s' "$slug" | grep -Eq -- '(^|-)(v[0-9]+|final|new|old|working|ready|wip|tmp|temp|test|draft)$' && fail "must not encode workflow state ('$rest')"
printf '%s' "$rest" | grep -Eq -- '(^|-)(changes|update|updates|fixes|misc|cleanup|stuff|new-version)$' && fail "generic name says nothing ('$rest')"
printf '%s' "$rest" | grep -Eq -- '-and-' && fail "one branch, one intent (split on 'and')"
printf '%s' "$rest" | grep -Eq -- '(^|-)[a-z]+\.(ts|tsx|js|py|rs|go|swift|kt|sql|md)(-|$)' && fail "must not name a file"
exit 0
