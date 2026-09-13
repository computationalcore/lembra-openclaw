# Contributing

Thank you for considering it. A few rules keep the history readable and the project safe to build on.

## Licensing of contributions

By submitting a contribution you agree that it is licensed under the Apache License 2.0, as
section 5 of that license already provides. No contributor agreement and no sign-off trailer is
required or wanted.

## Branches

`<type>/<semantic-name>`, lower-case kebab-case, describing the objective rather than the files:
`feature/scoped-erasure-receipts`, `bugfix/preserve-writer-order-on-replay`,
`refactor/separate-ledger-from-index`. Types: feature, bugfix, hotfix, release, support, refactor,
perf, docs, test, build, ci, chore.

## Commits

One line, business language, imperative: `type(scope): what changed for the system`.
Example: `fix(ledger): reject a record whose dependency is missing`. No body, no trailers, no
attribution lines of any kind. Squash merging keeps the pull request title as the commit subject.

## Pull requests

Title in the same `type(scope): outcome` form. Body with exactly two sections, `## What` and
`## Why`, each one or two sentences about behavior, not about files. Add `## Ref` only for a real
issue number. The `policy` check enforces all of this and will tell you which rule failed.

## Reviews

Changes to the record model, erasure semantics, retrieval scoring or anything security-relevant
need the maintainer's review. Everything else needs one approving review.

## Reporting a vulnerability

See [SECURITY.md](SECURITY.md). Do not open a public issue for it.
