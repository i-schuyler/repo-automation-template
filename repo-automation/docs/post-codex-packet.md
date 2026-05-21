# Post Codex Packet

`repo-automation/bin/post-codex-packet` assembles one uploadable review packet for the current repo state.

`repo-automation/bin/post-codex-review --packet` uses this helper to create the packet artifact and then reports the packet path in its default, `--explain`, and `--json` output.

## Behavior

- defaults to a packet root under `${REPO_AUTOMATION_OUTPUT_DIR:-${TMPDIR:-$HOME/.cache}/repo-automation}/post-codex`
- creates a timestamped packet directory and a sibling `.zip` archive
- writes a summary with branch, `HEAD`, timestamp, repo path, packet path, and zip path
- captures `git status --short`
- captures tracked unstaged and staged name lists, stats, and patches
- records untracked non-ignored files
- copies safe untracked files into the packet while skipping sensitive or oversized paths
- appends each packet to an index under the output base

## Safety Rules

Sensitive untracked files are skipped and recorded instead of copied. The helper skips at least:

- `.env` and `.env.*`
- `*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `*.p12`, `*.pfx`
- paths containing `token`, `secret`, `credential`, or `credentials`

Oversized untracked files are skipped when they exceed the default `262144` byte limit. Use `--max-bytes=<bytes>` to adjust that threshold.

## Output

Success prints the packet zip path.

## Options

- `--out-dir=<path>` overrides the output base
- `--label=<name>` adds a human-readable label to packet names
- `--keep-dir` keeps the packet directory after the zip is written
- `--max-bytes=<bytes>` changes the untracked copy size limit

## Examples

    repo-automation/bin/post-codex-packet
    repo-automation/bin/post-codex-packet --label=review
    repo-automation/bin/post-codex-packet --out-dir="${TMPDIR:-$HOME/.cache}/review-packets" --keep-dir
    repo-automation/bin/post-codex-packet --max-bytes=131072
