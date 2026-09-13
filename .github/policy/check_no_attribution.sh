#!/usr/bin/env bash
# Rejects tooling attribution in commit messages (a git range) and/or a PR body (a file).
# usage: check_no_attribution.sh [--repo <dir>] [--range <base>..<head>] [--body <file>]
set -u
range=""; body=""; repo="."
while [ $# -gt 0 ]; do case "$1" in --repo) repo="$2"; shift 2 ;; --range) range="$2"; shift 2 ;; --body) body="$2"; shift 2 ;; *) echo "unknown arg $1" >&2; exit 2 ;; esac; done
# Shape-based, vendor-free: any co-author trailer (this project credits co-authors in the PR,
# never in trailers), any '<Tool>-Session:' style trailer, any 'Generated with/by' line, the
# robot emoji, and session-style URLs. Naming vendors would age badly and say too much.
pat='^Co-Authored-By:|^Co-authored-by:|^[A-Za-z][A-Za-z-]*-?Session:|Generated (with|by) |🤖|https?://[^ ]+/(code|session)s?/[A-Za-z0-9_-]{6,}'
rc=0
if [ -n "$range" ]; then
  if ! out=$(git -C "$repo" log --format='%H%n%B%n----' "$range" 2>&1); then
    echo "attribution: cannot read range '$range' in '$repo' (a check that cannot read is a failed check)" >&2
    echo "  $out" >&2; exit 2
  fi
  if printf '%s' "$out" | grep -Eiq "$pat"; then
    echo "attribution: commit message in $range carries AI/tooling attribution" >&2
    git -C "$repo" log --format='%h %s' "$range" | sed 's/^/  /' >&2; rc=1
  fi
fi
if [ -n "$body" ] && [ -s "$body" ]; then
  if grep -Eiq "$pat" "$body"; then echo "attribution: PR body carries AI/tooling attribution" >&2; rc=1; fi
fi
exit $rc
