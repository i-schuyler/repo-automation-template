# Codex Status Timing UI Contract

Status: approved design contract

Scope: `repo-automation/bin/codex-status`, Codex timing/status display, and related contract tests.

## Purpose

`codex-status` reports Codex-specific operator state only.

It helps the operator answer:

- How much Codex limit remains?
- What was the latest tracked Codex invocation?
- How long did that invocation take?
- Which Codex session did it use?
- What is the summed elapsed time for tracked runs using that session?
- How do I resume that Codex session?

## Ownership

`codex-status` owns:

- Codex rate limits
- Codex invocation result
- Codex invocation elapsed time
- Codex model and reasoning
- Codex session id
- Codex session resume command
- Codex context remaining, when available
- Session totals calculated from tracked repo-automation Codex invocations

`codex-status --pretty` must not print workflow fields by default:

- branch
- PR number
- commit
- CI status
- pushed / merged / watched state
- review request path
- next workflow step
- slice-handoff blocker/fix framing

## Timing definitions

`elapsed` means wall-clock duration for one tracked `codex-run` invocation.

`elapsed` is sourced from `codex-run-summary.txt` fields:

- `elapsed`
- `elapsed_seconds`

Pretty output must show only formatted duration, for example `4m 41s`.

Pretty output must not show raw seconds.

`session total` means the sum of `elapsed_seconds` across all tracked repo-automation Codex runs that used the same Codex session id.

`session total` is not Codex active work time.

`session total` is not first-to-last JSONL timestamp span.

`session total` must not be inferred from `.codex/sessions/*.jsonl` timestamps.

The phrase `tracked runs` is required in session-total pretty output.

## Forbidden timing labels in pretty output

`codex-status --pretty` must not print:

- `work_time`
- `session_work_time`
- `timestamp_span`
- `session_timestamp_span`
- `active_work_time`
- `elapsed_seconds`
- `run_elapsed_seconds`

## Approved `codex-status --recent=1 --pretty` shape

```text
codex-status --recent=1 --pretty

limits
  5h:   44% left · resets 2026-06-15 00:15 UTC
  week: 61% left · resets 2026-06-18 18:08 UTC

recent runs
1. pass · 4m 41s · gpt-5.4-mini / medium
   session: 019ec1c2-3823-7051-a8a2-fd8c7cfa2b33
   session total: 9m 03s across 3 tracked runs
   context: 30% left
   resume:
     codex resume --include-non-interactive 019ec1c2-3823-7051-a8a2-fd8c7cfa2b33
```

## Rules

- The first content line of each run is result, elapsed, model / reasoning.
- The session id is printed once.
- The session total is printed once.
- Context is printed only when available.
- Resume command is printed when a session id is available.
- No workflow fields appear in this output.
- Machine JSON may keep raw seconds fields where needed for calculation, but pretty output must stay human-readable and ambiguity-free.
- If legacy `work_time` is preserved in JSON for compatibility, it must not be used for the new pretty UI and must not be used to compute session totals.

## Regression requirements

Future tests for this contract must assert:

1. `codex-status --recent=1 --pretty` does not print `work_time`.
2. `codex-status --recent=1 --pretty` does not print raw seconds fields.
3. `codex-status --recent=1 --pretty` prints one run elapsed value.
4. `codex-status --recent=1 --pretty` prints one session total calculated from tracked run elapsed values.
5. `codex-status --recent=1 --pretty` prints `tracked runs`.
6. `codex-status --recent=1 --pretty` does not print workflow fields:
   - branch
   - pr
   - commit
   - ci
   - next
   - pushed
   - merged
   - watched
7. Session totals are calculated from tracked `codex-run-summary.txt` elapsed values, not from Codex JSONL first-to-last timestamp spans.
8. Missing elapsed values must not be silently treated as real time. They should be omitted from totals or marked unavailable according to the JSON contract.
9. Pretty output remains compact and Codex-specific.

## Change control

This UI contract must not be changed incidentally during unrelated helper, workflow, or documentation work.

Any future change that adds workflow fields back into `codex-status --pretty`, reintroduces `work_time` into pretty output, or changes the meaning of `session total` must first update this contract and receive explicit approval.
