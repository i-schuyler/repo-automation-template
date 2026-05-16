# Review Pack

`repo-automation/bin/review-pack` creates a fallback review artifact or prompt without invoking Codex.

## Behavior

- `--target=chatgpt` creates an upload-friendly review bundle in `${REPO_AUTOMATION_OUTPUT_DIR:-${TMPDIR:-$HOME/.cache}/repo-automation}/review-pack`
- `--target=codex` creates a local prompt artifact only
- `--target=codex` does not invoke Codex
- uses existing evidence helpers where practical
- does not upload anything automatically
- does not write to the repo root by default

## Options

- `--target=<chatgpt|codex>` selects the audience/output form
- `--out-dir=<path>` overrides the output base
- `--label=<text>` adds a human label to the artifact names

## Output

Success prints a single artifact path:

- `--target=chatgpt` prints the review bundle zip path
- `--target=codex` prints the prompt file path

## Example

    repo-automation/bin/review-pack --target=chatgpt --label=review
    repo-automation/bin/review-pack --target=codex --out-dir=/tmp/review-pack
