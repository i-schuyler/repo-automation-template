# Status Packet

`repo-automation/bin/status-packet` prints a compact read-only repo snapshot for phone-first debugging.

Default human output includes:

- current branch
- `git status --short`
- touched tracked files, using the same commit-range fallback behavior as `repo-automation/bin/touched-files`
- untracked files, when present
- recent local `run-tests` and `repo-doctor` log paths, when discoverable
- latest PR metadata only when `gh` is available and a lookup is cheap enough to try

Supported flags:

- `--machine-json` returns machine-readable output.
- `--final-summary` returns the compact handoff block:

```text
===== FINAL SUMMARY =====
branch=<branch>
rc=<code>
output_lines=<n>
url_or_stop=<url|pass|STOP message>
status_count=<n>
===== END =====
```

Local mark/recap example:

```sh
FINAL_SUMMARY_AFTER_START_HOOK="mark: local workflow"
FINAL_SUMMARY_BEFORE_END_HOOK="recap: local workflow"
```

Examples:

    repo-automation/bin/status-packet
    repo-automation/bin/status-packet --machine-json
    repo-automation/bin/status-packet --final-summary

The helper does not print full diffs or full logs, and it skips PR lookup cleanly when `gh` is missing or unavailable.
