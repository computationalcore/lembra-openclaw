#!/usr/bin/env bash
# PR title = squash commit subject. Enforces the semantic-commits skill.
# usage: check_pr_title.sh "<title>"   exit 0 = ok, 1 = reject (reason on stderr)
set -u
title="${1-}"
fail() { echo "pr-title: $1" >&2; echo "  title: $title" >&2; exit 1; }
[ -n "$title" ] || fail "empty"
[ "${#title}" -le 80 ] || fail "longer than 80 characters"
types='feat|fix|refactor|perf|test|build|ci|docs|style|chore|ops|finding|merge'
printf '%s' "$title" | grep -Eq "^($types)\([a-z0-9][a-z0-9-]*\): " \
  || fail "must be 'type(scope): subject' with a house type and a lower-case kebab scope"
subject="${title#*: }"
printf '%s' "$subject" | grep -Eq '^[a-z]' || fail "subject must start lower-case"
printf '%s' "$subject" | grep -Eq '\.$' && fail "subject must not end with a period"
printf '%s' "$subject" | grep -Eq '[0-9]' && fail "subject must not contain digits (the tracker and the diff hold those)"
printf '%s' "$subject" | grep -Eq '[A-Za-z_-]+\.(ts|tsx|js|mjs|cjs|py|rs|go|swift|kt|kts|java|rb|sh|sql|yml|yaml|json|toml|md|css|html|xml|gradle)\b' \
  && fail "subject must not name a file"
printf '%s' "$subject" | grep -Eq '[a-z]+\(\)' && fail "subject must not name a function"
printf '%s' "$subject" | grep -Eqi '\b(ai|llm|bot|assistant)[- ](generated|written|assisted|authored)\b|generated (with|by) |co-authored' \
  && fail "subject must not describe how the work was produced"
generic='^(update|fix|changes|cleanup|wip|misc|stuff|fixes|more fixes|final fix|update files|fix stuff)( .*)?$'
printf '%s' "$subject" | grep -Eq "$generic" && fail "subject says nothing ('$subject')"
exit 0
