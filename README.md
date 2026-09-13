# lembra-openclaw

A [Lembra](https://github.com/computationalcore/lembra) plugin for the OpenClaw agent runtime.

**Status: spike.** This is the smallest useful thing a memory plugin can do inside a real host, kept
as the seed of the real adapter: an advisory check before an agent sends a message ("have I said
exactly this before?"), and a record of what was actually delivered. It writes no Lembra records yet;
it keeps a local fingerprint table, on purpose, until the record model is frozen.

## What it establishes

- **Hook choice is load-bearing.** `before_tool_call` fails closed, so a slow memory lookup there
  would stop the agent using its tools; `message_sending` fails open and is awaited; `message_sent`
  is observation only. The check lives on `message_sending`, the record on `message_sent`, and only
  on `success === true`, so a cancelled or failed send is never remembered as something said.
- **Settings come from `api.pluginConfig`**, not `api.config` (the host's own config). Reading the
  wrong one silently ignores every configured value.
- **Identity is `channelId` + `accountId`**, and no identity means no memory, never a shared
  fallback. `sessionKey` is deliberately excluded: "have I said this before" must span conversations.
- **Advisory by default.** `blockRepeats` is `false` unless set; the plugin observes and lets the
  message through.
- **A host deadline does not make slow work safe.** The 15 s timeout ends the host's await; it does
  not interrupt synchronous work. The lookup stays a prepared-statement read on a local file.

## Tests

```sh
node --test test.mjs
```

The suite drives a fake delivery transport that reproduces the host's real sequence
(`message_sending` → transport → `message_sent`), because calling the hooks in isolation hid every
defect it now pins. Three contract defects were found by review after the first passing suite and
are fixed and pinned: reading `api.config`, checking a non-existent `event.ok`, and namespacing on
`accountId` alone. Reintroducing each makes the suite fail; the checks are proven to fail on broken
input.

## What it does not establish

No gateway was started and no message was actually delivered, so hook *firing* in a live delivery
lane is still unproven; only registration in a real host is. Nothing here covers publication routes
other than `message_sending`, latency under load, the memory-slot delegation path, or Lembra ledger
semantics. Requires Node 24 (`node:sqlite`).

## License

Apache License 2.0. See LICENSE and NOTICE.
