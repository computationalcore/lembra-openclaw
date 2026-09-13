#!/usr/bin/env bash
# Mutation tests: every check must PASS its good inputs and FAIL its bad inputs.
# A checker that cannot fail on broken input is decoration.
set -u
cd "$(dirname "$0")"
pass=0; failn=0
expect() { # expect <0|1> <label> <cmd...>
  want="$1"; label="$2"; shift 2
  "$@" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$want" ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL [$label] wanted exit $want got $got: $*"; fi
}
T=./check_pr_title.sh; B=./check_branch_name.sh; A=./check_no_attribution.sh; P=./check_pr_body.sh
# --- PR titles
for t in "feat(onboarding): let a mistyped address be corrected at the code screen" \
         "fix(checkout): prevent a retry from being charged twice" \
         "refactor(payments): centralize payment state transitions" \
         "perf(search): avoid repeated ranking calculations" \
         "ops(tax): the accountant changed the fiscal year in the books" \
         "merge(core): support resumable onboarding"; do expect 0 "title ok" $T "$t"; done
for t in "update use-checkout.ts per review" "fix: update use-checkout.ts per review" \
         "fix(auth): update callback.ts and middleware" "chore: update dependencies" "feat: add stuff" \
         "Feat(auth): support resumable onboarding" "feat(auth): Support resumable onboarding" \
         "feat(auth): support resumable onboarding." "feat(Auth): support onboarding" \
         "fix(api): handle 429 from provider" "feat(memory): call loadGraph() earlier" \
         "docs(readme): generated with a tool" "feat(memory): ai-generated summary" "fix(booking): fix stuff" \
         "feat(booking): support recurring appointments and also fix the timezone bug and update the docs and more"; do expect 1 "title bad" $T "$t"; done
# --- branches
for b in feature/resumable-onboarding bugfix/prevent-overlapping-bookings hotfix/payment-webhook-idempotency \
         release/2.4.0 release/3.0.0-rc.1 support/1.x support/2.3 feature/VIN-142/resumable-onboarding \
         bugfix/BOOK-314/prevent-overlapping-bookings refactor/centralize-authorization-policy \
         perf/cache-embedding-lookups ci/validate-migrations-before-release main develop \
         bugfix/prevent-cross-tenant-memory-access; do expect 0 "branch ok" $B "$b"; done
for b in "feature/resumable_onboarding" "feature/ResumableOnboarding" "feature/resumable onboarding" \
         "fix/preserve-oauth-redirect" "feature/new-auth-hook-v2" "feature/resumable-onboarding-final" \
         "feature/changes" "bugfix/fixes" "chore/cleanup" "feature/wip" "feature/recurring-bookings-and-auth-fixes" \
         "release/september-updates" "support/customer-tickets" "feature/vin-auth-fix-v2" \
         "bugfix/prevent-users-from-being-able-to-access-memory-from-other-tenants" "feature/onboarding" \
         "feature/change-login.ts" "wip/anything-here" "feature/vin-142/lowercase-ticket-is-name-ok-but-too-long-x"; do expect 1 "branch bad" $B "$b"; done
# --- attribution, on a throwaway repo
tmp=$(mktemp -d); ( cd "$tmp" && git init -q -b main && git config user.email t@t && git config user.name t \
  && echo a > a && git add a && git commit -qm "feat(core): seed" \
  && echo b > b && git add b && git commit -qm "fix(core): prevent duplicate seed" \
  && git tag good \
  && echo c > c && git add c && git commit -qm "$(printf 'fix(core): prevent duplicate seed\n\nCo-Authored-By: Some Tool <tool@noreply.example.com>')" \
  && echo d > d && git add d && git commit -qm "$(printf 'docs(core): explain seeding\n\n🤖 Generated with a tool')" )
expect 0 "attribution clean range" $A --repo "$tmp" --range "good~1..good"
expect 1 "attribution trailer"     $A --repo "$tmp" --range "good..HEAD~1"
expect 1 "attribution whole range" $A --repo "$tmp" --range "good~1..HEAD"
expect 2 "attribution unreadable range" $A --repo "$tmp" --range "nope..HEAD"
printf '## What\n\nPrevents duplicate charges.\n\n## Why\n\nRetries re-charge.\n\nTool-Session: https://example.com/code/abc123def456\n' > "$tmp/body_bad"
printf '## What\n\nPrevents duplicate charges.\n\n## Why\n\nRetries re-charge.\n' > "$tmp/body_ok"
expect 1 "attribution body" $A --body "$tmp/body_bad"
expect 0 "attribution body ok" $A --body "$tmp/body_ok"
# --- PR body shape
printf '## What\n\nPrevents two appointments from being booked for the same provider and time.\n\n## Why\n\nConcurrent booking requests can currently pass availability validation before either reservation is persisted.\n\n## Ref\n\nBOOK-314\n' > "$tmp/b1"
expect 0 "body ok with ref" $P "$tmp/b1"
expect 0 "body ok no ref" $P "$tmp/body_ok"
printf '## What\n\nUpdated BookingService.ts and the repository.\n\n## Why\n\nRace.\n' > "$tmp/b2"; expect 1 "body narrates diff" $P "$tmp/b2"
printf '## What\n\nPrevents X.\n\n## Why\n\nY.\n\n## Ref\n\nN/A\n' > "$tmp/b3"; expect 1 "body ref n/a" $P "$tmp/b3"
printf '## What\n\nPrevents X.\n\n## Why\n\nY.\n\n## Test Plan\n\nran tests\n' > "$tmp/b4"; expect 1 "body auto section" $P "$tmp/b4"
printf '## What\n\nPrevents X.\n' > "$tmp/b5"; expect 1 "body missing why" $P "$tmp/b5"
printf '## What\n\nThis PR introduces safeguards.\n\n## Why\n\nY.\n' > "$tmp/b6"; expect 1 "body template phrase" $P "$tmp/b6"
printf '' > "$tmp/b7"; expect 1 "body empty" $P "$tmp/b7"
rm -rf "$tmp"
echo "policy tests: $pass passed, $failn failed"
[ "$failn" -eq 0 ]
