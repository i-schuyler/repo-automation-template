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

`slice-handoff` execution now routes through `codex-run` after preflight and still stops before `repo-flow submit`.

Future slice-handoff execution planning should validate profile existence and adapter compatibility before preflight, but that validation is not implemented here.
