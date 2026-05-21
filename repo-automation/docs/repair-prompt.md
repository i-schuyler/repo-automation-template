# Repair Prompt

`repo-automation/bin/repair-prompt` creates a compact prompt artifact from CI or local failure evidence.

## Behavior

- `--source=ci` gathers CI evidence when needed, preferring `ci-log-dump --first-failure --machine-json`
- `--source=local` gathers local failure evidence when needed
- `--target=codex` creates a prompt artifact only
- stops cleanly when required evidence does not exist
- does not patch code
- does not include secrets or private config
- does not write to the repo root by default

## Prompt content

The generated prompt includes:

- Task
- Goal
- Scope
- Failure evidence excerpt
- Required behavior
- Not in scope
- Checks required
- Output contract

## Options

- `--source=<ci|local>` selects the evidence source
- `--target=codex` is required
- `--evidence-file=<path>` uses a pre-generated evidence file
- `--pr=<number>` selects a PR when gathering CI evidence
- `--run-id=<id>` selects a run when gathering CI evidence
- `--out-dir=<path>` overrides the output base

## Output

Success prints the prompt file path.

## Example

    repo-automation/bin/repair-prompt --source=ci --target=codex --pr=123
    repo-automation/bin/repair-prompt --source=local --target=codex --out-dir="${TMPDIR:-$HOME/.cache}/repair-prompt"
