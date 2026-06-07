# Codex Status Helper Spec

`repo-automation/bin/codex-status` is implemented as a read-only, JSON-first helper.

## Purpose

Report Codex session, token, context, resume, re-entry, rate-limit, and recent-session status from Codex JSONL session files.

## Phase 1 CLI

```sh
repo-automation/bin/codex-status [--latest|--session-id=<id>|--session-file=<path>|--recent[=<n>]] [--repo-root=<path>] [--session] [--usage] [--limits] [--resume] [--reentry] [--all] [--pretty] [--verbose] [--check-limits] [--warn-remaining-at=<percent>] [--block-remaining-at=<percent>] [--help]
```

Defaults:

- output is compact JSON on stdout
- report mode defaults to `--all`
- remaining thresholds default to `--warn-remaining-at=15` and `--block-remaining-at=7`
- session discovery uses `CODEX_HOME` when set, otherwise `$HOME/.codex`
- `--recent` defaults to 5 recent sessions and `--recent=<n>` caps at 50

Implemented behavior:

- read-only; no Codex writes
- `--pretty` emits compact operator-readable text
- `--verbose` adds token breakdown details to `--pretty` single-session output
- `--session`, `--usage`, `--limits`, `--resume`, `--reentry`, and `--all` are supported
- single-session selection supports `--latest`, `--session-id=<id>`, `--session-file=<path>`, and `--repo-root=<dir>`
- `--recent` discovers the most recent Codex sessions without the interactive `codex resume` picker
- `--help --pretty` prints the grouped phone-friendly help menu
- `--check-limits` exits `2` when a block-threshold condition is selected
- unsupported Phase 1 flags fail with exit `1` and a fix hint

Unsupported in Phase 1:

- `--human`
- `--quiet`
- `--all-sessions`
- `--blocker-summary`
- `--warn-at=<percent>`
- `--block-at=<percent>`
- `--strong-warn-at=<percent>`

## Single-session JSON contract

Top-level fields:

- `schema`
- `ok`
- `status`
- `generated_at`
- `codex`
- `selector`
- `mtime`
- `mtime_local`
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
- `mtime` and `mtime_local` should describe the selected session file timestamp when available
- `session.source` and `session.originator` should be populated when present
- `git.branch`, `git.commit`, and `git.repository_url` should be parsed from nested `session_meta.payload.git` first, with flat fallbacks preserved for compatibility
- `model.name` should come from turn context when available; `model.reasoning` should prefer `turn_context.payload.collaboration_mode.settings.reasoning_effort`, then `turn_context.payload.effort`, then `turn_context.payload.reasoning`
- `tokens` should expose both current/last-context totals and cumulative totals when present
- `token_count` is read from `event_msg.payload.info.total_token_usage`, while current-context usage comes from `event_msg.payload.info.last_token_usage`
- `rate_limits.primary` maps to five-hour status and `rate_limits.secondary` maps to weekly status
- `rate_limits.primary.resets_at` and `rate_limits.secondary.resets_at` are epoch seconds and should be rendered as UTC ISO and local reset times in recent output
- `context.remaining` should be `model_context_window - last_token_usage.total_tokens` when available
- `context.used_percent` and `context.remaining_percent` should be numeric when calculable
- `context.remaining_summary` should be compact human-readable text when calculable, otherwise `unknown`
- context remaining must never go negative; if the current total exceeds the window, set context fields to null and warn
- rate limits are separate from token usage and context usage; keep their fields separate in JSON and pretty output
- `limits.five_hour` and `limits.weekly` should include `used_percent`, `remaining_percent`, `window_minutes`, `state`, and thresholds
- `limits.five_hour.percent` and `limits.weekly.percent` are compatibility aliases for `used_percent`
- session id should prefer `payload.session_id`, then `payload.id`, then a UUID-like filename stem, then the filename stem with a warning
- `limit.state` is `unknown`, `ok`, `warn`, or `block`
- `warn` means remaining percent is at or below `--warn-remaining-at`
- `block` means remaining percent is at or below `--block-remaining-at`
- `resume.resume_commands` should include interactive and non-interactive resume shapes when `session_id` is known
- `reentry` should include decision inputs for `resume_without_compact`, `compact_then_resume`, and `start_fresh`
- `compact_then_resume` is unsupported or unproven in Phase 1 unless supported behavior is later documented
- `warnings` and `errors` are arrays
- `ok` is `false` only for actual errors, not for unknown optional metadata

## Recent JSON contract

`--recent` and `--recent=<n>` return a bounded recent-session list.
Recent `rate_limits` stay top-level and separate from each session's token and context data.

Top-level fields:

- `schema` = `repo-automation-codex-status-recent/v1`
- `ok`
- `result`
- `status`
- `generated_at`
- `codex`
- `selector`
- `rate_limits`
- `sessions`
- `warnings`
- `errors`
- `next`

Top-level `rate_limits` fields:

- `limit_id`
- `plan_type`
- `rate_limit_reached_type`
- `five_hour.used_percent`
- `five_hour.remaining_percent`
- `five_hour.window_minutes`
- `five_hour.resets_at`
- `five_hour.resets_at_iso`
- `five_hour.resets_at_local`
- `weekly.used_percent`
- `weekly.remaining_percent`
- `weekly.window_minutes`
- `weekly.resets_at`
- `weekly.resets_at_iso`
- `weekly.resets_at_local`

Each `sessions[]` item includes:

- `ordinal`
- `session_id`
- `session_file`
- `mtime`
- `mtime_local`
- `source`
- `originator`
- `git.branch`
- `git.commit`
- `git.repository_url`
- `model.name`
- `model.reasoning`
- `tokens.current_total`
- `tokens.cumulative_total`
- `context.remaining`
- `context.remaining_percent`
- `context.remaining_summary`
- `resume.command`
- `resume.commands`

## Exit codes

- `0` successful status generation, including warning-only states
- `1` invalid flags, missing or unreadable selected session metadata, parse errors, or unexpected tool failure
- `2` `--check-limits` found a block-threshold condition requiring explicit operator override

## Future work

Recent-session discovery is now a bounded list mode through `--recent`; richer multi-session views are still out of scope.
