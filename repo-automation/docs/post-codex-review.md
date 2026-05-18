# Post Codex Review

`repo-automation/bin/post-codex-review` is the operator handoff helper for the current repo state. Its default output is a compact FINAL SUMMARY block.

## Behavior

- default output is a compact `===== FINAL SUMMARY =====` block
- `--quiet` stays silent on success and prints only the first actionable failure
- `--json` emits compact JSON only on stdout
- `--explain` prints human/operator details and still ends with a single `===== FINAL SUMMARY =====` block
- the summary stays within 25 lines
- the summary can include `FINAL_SUMMARY_AFTER_START_HOOK` and `FINAL_SUMMARY_BEFORE_END_HOOK` lines from `.repo-automation.local.conf`
- includes branch, status count, changed, staged, untracked, first-failure label, log path, and packet path
- does not print diffs or long logs
- if a recent `run-tests` or `repo-doctor` failure log is available, it reports only the log path and first failure label when that is cheap to discover

## Packet Mode

- `--packet` is an action modifier, not an output mode
- it uses `repo-automation/bin/post-codex-packet` to create the packet bundle and records the packet zip path in the output

## JSON

`--json` returns only these fields:

- `script` (`"post-codex-review"`)
- `status` (`"pass"` or `"fail"`)
- `branch` (string)
- `status_count` (number)
- `changed` (array of strings)
- `staged` (array of strings)
- `untracked` (array of strings)
- `first_failure` (string or `null`)
- `log` (string or `null`)
- `packet` (string or `null`)

## Examples

    repo-automation/bin/post-codex-review
    repo-automation/bin/post-codex-review --packet

This helper is intended for the last step before operator review: use it instead of custom shell blocks when you want one concise repo-native summary.
