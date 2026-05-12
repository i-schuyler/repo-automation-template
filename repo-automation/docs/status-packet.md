# Status Packet

`repo-automation/bin/status-packet` prints a compact read-only repo snapshot for phone-first debugging.

Default human output includes:

- current branch
- `git status --short`
- touched tracked files, using the same commit-range fallback behavior as `repo-automation/bin/touched-files`
- untracked files when the touched-files helper falls back to working-tree mode
- recent local `run-tests` and `repo-doctor` log paths, when discoverable
- latest PR metadata only when `gh` is available and a lookup is cheap enough to try

Supported flags:

- `--machine-json` returns machine-readable output.

Examples:

    repo-automation/bin/status-packet
    repo-automation/bin/status-packet --machine-json

The helper does not print full diffs or full logs, and it skips PR lookup cleanly when `gh` is missing or unavailable.
