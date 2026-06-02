# Codex Run

`repo-automation/bin/codex-run` is the public adapter around `codex exec`.

## What it does

- reads a prompt file
- runs `codex exec` with argv construction, not shell eval
- writes `codex.stdout`, `codex.stderr`, `codex-final.txt`, `codex-final-output-block.txt`, and `codex-run-summary.txt` into the requested out-dir
- supports `--quiet` and `--explain`
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

## Test contract

The contract tests inject a fake `codex` binary through `PATH`, so CI does not require a real Codex install.

## Relationship to slice-handoff

`slice-handoff` execution routes through `codex-run` after preflight. `slice-handoff` execution can now continue from `codex-run` to PR-body validation and repo-flow submit only when bare `--submit` authorizes the submit boundary, and still stops before merge.

Future slice-handoff execution planning should validate profile existence and adapter compatibility before preflight, but that validation is not implemented here.

For public-safe interactive/resume/session metadata observations and future helper direction, see [Codex Session Resume and Metadata](codex-session-resume.md).
