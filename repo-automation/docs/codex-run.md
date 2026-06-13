# Codex Run

`repo-automation/bin/codex-run` is the public adapter around `codex exec` and `codex exec resume` session re-entry.

## What it does

- reads a prompt file
- runs `codex exec` by default, or `codex exec resume <session-id> <prompt>` when `--resume-session-id=<id>` is set
- uses argv construction, not shell eval
- writes `codex.stdout`, `codex.stderr`, `codex-final.txt`, `codex-final-output-block.txt`, and `codex-run-summary.txt` into the requested out-dir when final-output capture succeeds
- supports `--quiet` and `--explain`
- records `resume_mode=fresh` or `resume_mode=resume` in `codex-run-summary.txt`
- records requested model/reasoning in `codex-run-summary.txt` when they are supplied
- forwards `--cd`, `--sandbox`, `--profile`, and `--model` into `codex exec` / `codex exec resume`
- accepts optional `--model=<model-name>` and `--reasoning=<low|medium|high>` inputs, then forwards model as `--model` and reasoning as `-c model_reasoning_effort=<level>`
- does not pass an approval-policy flag to `codex exec`; it relies on the selected sandbox mode and avoids dangerous bypass flags
- does not implement `--json` in this slice

## Usage

```sh
repo-automation/bin/codex-run --prompt-file=prompt.txt --out-dir=/path/to/codex-run-out
```

In `--explain` mode, successful runs print the `FINAL SUMMARY` first and then a copy/paste block on stderr:

```text
===== CODEX FINAL OUTPUT =====
...
===== END CODEX FINAL OUTPUT =====
```

The block content comes from `codex-final.txt`. Default non-explain output stays compact, and `codex-run-summary.txt` stays key=value machine-readable.

Quiet failures use Quiet Diagnostic Envelope v1 on stderr: `result=fail`, `code`, `step`, `reason`, `fix`, and optional `log`/`artifact`/`excerpt` fields. Child-process failures keep the child stdout/stderr artifacts, final-output contract failures name the missing or empty `codex-final.txt`, resume-mode final-output failures use an explicit `resume-final-output-contract-failed` envelope instead of copying `codex.stdout` into `codex-final.txt`, and block-write failures name the block artifact path.

Output modes stay mutually exclusive. `--quiet --explain` fails compactly before Codex runs, `--json` remains unsupported, and `--quiet --json` / `--json --explain` do not invoke Codex.

Default failures stay compact and human-readable with step, exit code when relevant, reason, excerpt, log/artifact path, and fix.

## Test contract

The contract tests inject a fake `codex` binary through `PATH`, so CI does not require a real Codex install.

## Relationship to slice-handoff

`slice-handoff` execution routes through `codex-run` after preflight. `slice-handoff` execution can now continue from `codex-run` to PR-body validation and repo-flow submit only when bare `--submit` authorizes the submit boundary, and still stops before merge.

Resume mode is intentionally narrower than fresh exec: it uses `codex exec resume` so `--cd`, `--sandbox`, `--profile`, `--model`, and `--output-last-message` remain argv-driven, and it fails explicitly if a reliable final-output artifact does not appear. Reasoning is passed through `-c model_reasoning_effort=<level>`. The adapter does not synthesize `codex-final.txt` from stdout.

Future slice-handoff execution planning should validate profile existence and adapter compatibility before preflight, but that validation is not implemented here.

For public-safe interactive/resume/session metadata observations and future helper direction, see [Codex Session Resume and Metadata](codex-session-resume.md).

For the future one-helper status plan, see [Codex Status Helper Spec](codex-status.md).
