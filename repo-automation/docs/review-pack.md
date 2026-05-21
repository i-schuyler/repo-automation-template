# Review Pack

`repo-automation/bin/review-pack` creates a fallback review artifact or prompt without invoking Codex.

## Behavior

- `--target=review` creates a lean, phone-friendly post-codex packet by default
- `--target=review --full` creates the heavier evidence bundle with repo zip
- `--target=review` can optionally copy or scp the final artifact
- `--target=codex` creates a local prompt artifact only
- `--target=codex` does not invoke Codex
- uses existing evidence helpers where practical
- does not upload anything automatically
- does not write to the repo root by default

## Options

- `--target=<review|codex>` selects the audience/output form
- `--out-dir=<path>` overrides the output base
- `--label=<text>` adds a human label to the artifact names
- `--full` switches review mode from lean to full
- `--copy-to=<dir>` copies the review zip to a local directory
- `--scp-to=<target>` sends the review zip to an scp destination
- `--no-transfer` disables `.repo-automation.local.conf` transfer defaults
- `--explain` appends the final summary block

## Output

Success prints a single artifact path:

- `--target=review` prints the lean packet zip path
- `--target=review --full` prints the full bundle zip path
- `--target=review --copy-to=<dir>` prints the copied artifact path
- `--target=review --scp-to=<target>` prints the supplied scp target
- `--target=codex` prints the prompt file path

With `--explain`, `--target=review` ends with:

    ===== FINAL SUMMARY =====
    artifact=/path/to/review-packets/example.zip
    packet_mode=lean
    transfer=none
    destination=none
    output=/path/to/review-packets/example.zip
    size_bytes=12345
    status_count=0
    ===== END =====

## Example

    repo-automation/bin/review-pack --target=review --label=review
    repo-automation/bin/review-pack --target=review --full --label=review
    repo-automation/bin/review-pack --target=review --copy-to=/path/to/review-packets/delivery
    repo-automation/bin/review-pack --target=review --scp-to=review-bundle@example.org:/path/to/review-packets/example.zip
    repo-automation/bin/review-pack --target=review --no-transfer
    repo-automation/bin/review-pack --target=review --explain
    repo-automation/bin/review-pack --target=codex --out-dir=/path/to/review-packets/codex

## Local Defaults

`.repo-automation.local.conf` can set optional review-pack transfer defaults:

    REVIEW_PACK_COPY_TO=/path/to/review-packets/delivery
    REVIEW_PACK_SCP_TO=review-bundle@example.org:/path/to/review-packets/example.zip

Only one default transfer destination should be set at a time. Use `--no-transfer` to ignore local defaults for a run.

`--copy-to` and `--scp-to` override local defaults, and `--no-transfer` bypasses them.
