# Codex Status Helper Spec

`repo-automation/bin/codex-status` is implemented as a read-only, JSON-first Phase 1 helper.

## Purpose

Report Codex session, token, context, resume, re-entry, and rate-limit status from Codex JSONL session files.

## Phase 1 CLI

```sh
repo-automation/bin/codex-status [--latest|--session-id=<id>|--session-file=<path>] [--repo-root=<dir>] [--session] [--usage] [--limits] [--resume] [--reentry] [--all] [--pretty] [--check-limits] [--warn-remaining-at=<percent>] [--block-remaining-at=<percent>] [--help]
```

Defaults:

- output is compact JSON on stdout
- report mode defaults to `--all`
- remaining thresholds default to `--warn-remaining-at=15` and `--block-remaining-at=7`
- session discovery uses `CODEX_HOME` when set, otherwise `$HOME/.codex`

Implemented behavior:

- read-only; no Codex writes
- `--pretty` emits compact operator-readable text
- `--session`, `--usage`, `--limits`, `--resume`, `--reentry`, and `--all` are supported
- single-session selection supports `--latest`, `--session-id=<id>`, `--session-file=<path>`, and `--repo-root=<dir>`
- `--check-limits` exits `2` when a block-threshold condition is selected
- unsupported Phase 1 flags fail with exit `1` and a fix hint

Unsupported in Phase 1:

- `--human`
- `--quiet`
- `--all-sessions`
- `--recent=<n>`
- `--blocker-summary`
- `--warn-at=<percent>`
- `--block-at=<percent>`
- `--strong-warn-at=<percent>`

## JSON contract

Top-level fields:

- `schema`
- `ok`
- `status`
- `generated_at`
- `codex`
- `selector`
- `session`
- `git`
- `model`
- `tokens`
- `context`
- `limits`
- `resume`
- `reentry`
- `warnings`
- `errors`
- `next`

Field notes:

- `session.session_id` should resolve from session metadata or filename when possible
- `session.source` and `session.originator` should be populated when present
- `git.branch`, `git.commit`, and `git.repository_url` should be parsed when available
- `model.name` and `model.reasoning` should come from turn context when available
- `tokens` should use the latest token-count event
- `context.remaining` should be `model_context_window - total tokens` when available
- `context.used_percent` and `context.remaining_percent` should be numeric when calculable
- `context.remaining_summary` should be compact human-readable text when calculable
- `limits.five_hour` and `limits.weekly` should include `percent`, `state`, `window_minutes` when known, and thresholds
- `limit.state` is `unknown`, `ok`, `warn`, or `block`
- `warn` means remaining percent is at or below `--warn-remaining-at`
- `block` means remaining percent is at or below `--block-remaining-at`
- `resume.resume_commands` should include interactive and non-interactive resume shapes when `session_id` is known
- `reentry` should include decision inputs for `resume_without_compact`, `compact_then_resume`, and `start_fresh`
- `compact_then_resume` is unsupported or unproven in Phase 1 unless supported behavior is later documented
- `warnings` and `errors` are arrays
- `ok` is `false` only for actual errors, not for unknown optional metadata

## Exit codes

- `0` successful status generation, including warning-only states
- `1` invalid flags, missing or unreadable selected session metadata, parse errors, or unexpected tool failure
- `2` `--check-limits` found a block-threshold condition requiring explicit operator override

## Future work

Phase 2+ may integrate `codex-status` into other helpers or add richer multi-session views. That integration is not part of Phase 1.
