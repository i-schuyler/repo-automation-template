# Codex Run

`repo-automation/bin/codex-run` is the public adapter around `codex exec`.

## What it does

- reads a prompt file
- runs `codex exec` with argv construction, not shell eval
- writes `codex.stdout`, `codex.stderr`, `codex-final.txt`, and `codex-run-summary.txt` into the requested out-dir
- supports `--quiet` and `--explain`
- does not pass an approval-policy flag to `codex exec`; it relies on the selected sandbox mode and avoids dangerous bypass flags
- does not implement `--json` in this slice

## Usage

```sh
repo-automation/bin/codex-run --prompt-file=prompt.txt --out-dir=/path/to/codex-run-out
```

## Test contract

The contract tests inject a fake `codex` binary through `PATH`, so CI does not require a real Codex install.

## Relationship to slice-handoff

`slice-handoff` execution routes through `codex-run` after preflight. Without bare `--submit`, it still stops before `repo-flow submit`; with bare `--submit` and `submit_mode: repo-flow-submit-all`, later slice-handoff phases continue to PR body validation and repo-flow submit.

Future slice-handoff execution planning should validate profile existence and adapter compatibility before preflight, but that validation is not implemented here.
