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
- `--explain` emits a compact handoff block for operator review:

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
FINAL_SUMMARY_AFTER_START_HOOK="mark"
FINAL_SUMMARY_BEFORE_END_HOOK="recap"
```

The FINAL SUMMARY block stays compact and must remain at or below 25 lines.
When present, those hook values come from `.repo-automation.local.conf`, not the tracked config.

## `--machine-json`

`--machine-json` returns only these fields:

- `script` (`"status-packet"`)
- `machine_json` (`true`)
- `branch` (string)
- `status_short` (string)
- `changed_tracked_files` (array of strings)
- `untracked_files` (array of strings)
- `recent_logs.run_tests` (string)
- `recent_logs.repo_doctor` (string)
- `latest_pr.available` (boolean)
- `latest_pr.number` (string)
- `latest_pr.title` (string)
- `latest_pr.state` (string)
- `latest_pr.url` (string)
- `latest_pr.head_ref` (string)
- `latest_pr.base_ref` (string)
- `warnings` (array of strings)
- `overall_status` (string)

Examples:

    repo-automation/bin/status-packet
    repo-automation/bin/status-packet --explain
    repo-automation/bin/status-packet --machine-json

The helper does not print full diffs or full logs, and it skips PR lookup cleanly when `gh` is missing or unavailable.
