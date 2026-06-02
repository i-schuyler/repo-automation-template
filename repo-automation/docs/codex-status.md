# Codex Status Helper Spec

This is a public-safe spec only. The helper described here is not implemented yet.

## Purpose

Plan a single future helper, `repo-automation/bin/codex-status`, that reports Codex session, resume, token, context, and rate-limit status for both humans and automation.

## Design goals

- one helper with flags/modes, not a family of separate helpers
- JSON-first output for scripting
- optional human rendering only with an explicit flag such as `--human`
- stdout carries requested status output; stderr carries diagnostics only
- do not require automation callers to scrape human text
- preserve deterministic slice-handoff boundaries
- keep current behavior distinct from planned behavior

## Proposed CLI surface

```sh
repo-automation/bin/codex-status [--latest|--session-id=<id>|--session-file=<path>] [--repo-root=<dir>] [--all-sessions|--recent=<n>] [--session] [--usage] [--limits] [--resume] [--all] [--check-limits] [--warn-at=<percent>] [--strong-warn-at=<percent>] [--block-at=<percent>] [--human] [--pretty] [--quiet]
```

Recommended defaults:

- default to JSON on stdout
- `--human` enables operator-friendly rendering
- `--pretty` may prettify JSON when JSON output is selected
- `--quiet` suppresses nonessential human chatter, not the contract output

Selection rules:

- `--latest` chooses the newest readable session
- `--session-id=<id>` selects one known session
- `--session-file=<path>` reads a specific JSONL session file
- `--repo-root=<dir>` scopes repository-relative metadata and git info
- `--all-sessions` or `--recent=<n>` can enumerate multiple sessions

Report modes:

- `--session` reports identity and provenance
- `--usage` reports tokens, cached input tokens, and context remaining
- `--limits` reports 5-hour and weekly rate-limit proximity
- `--resume` reports possible resume commands and resume suitability
- `--reentry` or `--blocker-summary` reports compact blocker/re-entry status for operator handoff
- `--all` is the combined report mode
- `--check-limits` makes rate-limit thresholds affect exit status

Threshold controls:

- `--warn-at=<percent>` defaults around `75`
- `--strong-warn-at=<percent>` defaults around `85`
- `--block-at=<percent>` defaults around `92`

Resume policy direction:

- same-model resume with changed reasoning may be allowed when intentional and recorded
- different-model resume should be avoided by default
- avoid resuming sessions after more than 1-2 compactions or a major context shift

## Blocker and re-entry status

Future blocker output should be compact enough to paste into ChatGPT/operator review after a failed helper flow.

Preferred behavior:

- JSON-first by default for automation and re-entry tooling
- explicit `--human` only for operator-friendly rendering
- compact blocker output should either include the re-entry status directly or point to a JSON artifact plus a short human summary
- the compact re-entry payload should make the resume decision obvious without scraping prose

Decision targets for the re-entry payload:

- `resume_without_compact`
- `resume_with_compact`
- `start_fresh`

The status should summarize the current session, the resume candidates, and the key decision inputs needed for ChatGPT/operator judgment.

## Public facts to preserve

- Codex session metadata can be read from JSONL session files.
- Useful observed event types include `session_meta`, `turn_context`, `event_msg`, and `response_item`.
- Token-count events can include input tokens, cached input tokens, output tokens, reasoning output tokens, total tokens, model context window, plan type, and primary/secondary rate-limit window percentages.
- Approximate remaining context can be derived as `model_context_window - total_tokens`.
- Current helpers do not yet implement session metadata scraping or rate-limit warnings.

## Draft JSON contract

```json
{
  "schema": "repo-automation-codex-status/v1",
  "ok": true,
  "status": "ok",
  "generated_at": "2026-06-02T00:00:00Z",
  "codex": {
    "helper": "repo-automation/bin/codex-status",
    "mode": "all",
    "version": null
  },
  "selector": {
    "kind": "latest",
    "session_id": null,
    "session_file": null,
    "repo_root": "."
  },
  "session": {
    "session_id": null,
    "resumeable": false,
    "resume_commands": [],
    "source": null,
    "originator": null,
    "cwd": null,
    "branch": null,
    "commit": null,
    "compactions": 0,
    "event_types": ["session_meta", "turn_context", "event_msg", "response_item"]
  },
  "git": {
    "repo_root": ".",
    "branch": null,
    "commit": null,
    "dirty": null
  },
  "model": {
    "name": null,
    "reasoning": null,
    "plan_type": null,
    "context_window": null
  },
  "tokens": {
    "input": null,
    "cached_input": null,
    "output": null,
    "reasoning_output": null,
    "total": null
  },
  "context": {
    "remaining": null,
    "approx_remaining": null,
    "used_percent": null,
    "remaining_percent": null,
    "remaining_summary": null
  },
  "limits": {
    "five_hour": {
      "percent": null,
      "state": "unknown",
      "warn_at": 75,
      "strong_warn_at": 85,
      "block_at": 92
    },
    "weekly": {
      "percent": null,
      "state": "unknown",
      "warn_at": 75,
      "strong_warn_at": 85,
      "block_at": 92
    }
  },
  "resume": {
    "allowed": null,
    "model_match": null,
    "reasoning_change_recorded": null,
    "recommendation": null,
    "decision_inputs": {
      "resume_without_compact": null,
      "resume_with_compact": null,
      "start_fresh": null
    }
  },
  "warnings": [],
  "errors": [],
  "next": []
}
```

Implementation may add fields, but it should not remove or repurpose these without a new schema version.

## Exit codes

- `0`: successful status generation, including warning-only states
- `1`: invalid input, missing or unreadable session metadata, parse errors, or unexpected tool failure
- `2`: `--check-limits` found a block-threshold condition requiring explicit operator override

## Integration plan

Phase 1: implement `codex-status` as a read-only helper with tests.

Phase 2: have `codex-run` write session metadata artifacts or consume `codex-status` results after exec.

Phase 3: have `slice-handoff` surface resume/status artifacts in blocker and re-entry contexts.

Phase 4: optionally add a preflight warning gate for rate-limit thresholds.

Direct interactive TUI launch inside `slice-handoff` stays out of scope.

## Future test coverage

- JSON schema/shape
- fixture JSONL parsing
- latest/session-id/session-file selection
- token and context calculations
- rate-limit warning thresholds
- resume-command generation
- stdout/stderr purity
- no private path leakage in public tests or docs
- managed-file and installer coverage once the helper is implemented

## Related docs

- [Codex Session Resume and Metadata](codex-session-resume.md)
- [Codex Run](codex-run.md)
- [Slice Handoff](slice-handoff.md)
