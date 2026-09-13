#!/usr/bin/env bash
# Enforces the pr-descriptions skill shape: '## What' and '## Why' present and non-empty,
# '## Ref' only with a real id, no auto-added sections, no diff narration phrases.
# usage: check_pr_body.sh <file>
set -u
f="${1-}"; fail() { echo "pr-body: $1" >&2; exit 1; }
[ -s "$f" ] || fail "empty PR description; needs '## What' and '## Why'"
section() { awk -v h="## $1" '$0==h{p=1;next} /^## /{p=0} p' "$f" | sed '/^[[:space:]]*$/d'; }
[ -n "$(section What)" ] || fail "'## What' is missing or empty"
[ -n "$(section Why)"  ] || fail "'## Why' is missing or empty"
if grep -q '^## Ref' "$f"; then
  ref="$(section Ref)"
  [ -n "$ref" ] || fail "'## Ref' present but empty; drop the section"
  printf '%s' "$ref" | grep -Eqi '^(n/?a|none|-)$' && fail "'## Ref' must be a real ticket id or be omitted"
fi
grep -Eq '^## (Changes|Summary|Implementation|Technical Details|Files Changed|Testing|Test Plan|Notes|Checklist)' "$f" \
  && fail "auto-added section; only What / Why / Ref by default"
grep -Eiq '^(This PR introduces|This change ensures|In order to)|\b(Updated|Modified|Changed|Refactored) (the )?[A-Za-z]+\.(ts|py|rs|swift|kt|js)\b' "$f" \
  && fail "narrates the diff or uses template phrasing; describe behavior"
exit 0
