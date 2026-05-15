# Repo Automation Output Modes

Status: approved draft canon
Repo target: `repo-automation-template`
Intended repo path after approval: `repo-automation/docs/output-modes.md`
Purpose: define the newest quiet-first output contract for repo automation helpers.

This document replaces older output-mode language. The newest design is the only design.

## Core rule

Every repo automation helper should output the least information that is still useful.

Success should be quiet. Failure should be actionable. Diagnostics should be narrow.

Do not make the user hunt for the important line.

## Status words

Canonical human status words are lowercase:

- `pass`
- `fail`
- `warn`
- `skip`
- `wait`
- `plan`
- `clean`
- `none`

Use lowercase because it is consistent, easy to snapshot-test, easy to parse, and visually calm.

Do not choose status-word capitalization based on assumed token savings.

## Output postures

Every public helper should fit one of these output postures.

| Posture | Purpose | Success output | Failure output |
| --- | --- | --- | --- |
| Default human compact | readable phone-friendly output | `pass`, artifact path, or compact result | first actionable failure plus fix |
| `--quiet` | least UI and agent-token noise | no output | first actionable failure only |
| JSON mode | machine-readable output | valid JSON only on stdout | valid JSON only on stdout |

Do not add `--agents` unless a future need cannot be expressed with `--quiet`, `--json`, or `--machine-json`.

For Codex or other agent checks, prefer `--quiet` for minimal human-readable checks. Use JSON only when structured parsing is needed.

## Stream rules

- Default human success output goes to stdout.
- Artifact paths go to stdout.
- Human warnings and failures go to stderr.
- JSON modes write valid JSON only to stdout.
- Non-JSON diagnostics must not mix into JSON stdout.
- `--help` writes usage to stdout.

If a script cannot produce valid JSON, it must fail outside JSON mode with a compact human failure instead of printing partial JSON.

## Default human compact mode

Default output prints only the final useful result.

Successful generic check:

```text
pass
```

Warning-only run:

```text
warn: gh unavailable; skipped GitHub settings readiness
```

Failure:

```text
fail: docs-check: broken link in docs/INDEX.md
excerpt: repo-automation/docs/command-shape.md not found
fix: add the doc or update docs/INDEX.md
```

Rules:

- Do not print every passing check.
- Do not print child-script status from umbrella scripts.
- Do not print decorative headings.
- Do not print a log path on clean success unless the command's purpose is to create an artifact or log.

## Quiet mode

`--quiet` is the lowest-noise human-readable mode.

Successful quiet run:

```text
```

Failure in quiet mode:

```text
fail: shellcheck missing
fix: pkg install shellcheck
```

Warning-only quiet run:

```text
warn: gh unavailable; skipped GitHub settings readiness
```

Rules:

- Print nothing when all checks pass.
- Print warning-only output when there are warnings but no failures.
- Print only the first actionable failure when a failure occurs.
- Do not print child-script status from umbrella scripts.
- Do not print log paths unless the log path is required for the smallest next action.

## Explain mode

`--explain` is the detailed human escape hatch.

Use it when a person needs all relevant warnings, failures, summaries, or log paths.

Example:

```text
fail: 1 blocker, 1 warning
blocker: docs-check: broken link in docs/INDEX.md
warning: gh unavailable; skipped GitHub settings readiness
log: ${TMPDIR:-$HOME/.cache}/repo-automation-template/repo-doctor-2026-05-14T215100.log
```

Rules:

- `--explain` may include pass/warn/fail counts.
- `--explain` may include multiple findings.
- `--explain` still must not dump long raw logs by default.
- If a long log matters, print the exact log path and the smallest useful excerpt.

## JSON modes

Scripts may expose `--json`, `--machine-json`, or both.

Rules:

- stdout must be valid JSON only.
- stderr may contain fatal wrapper errors only when JSON cannot be produced.
- `--json-level=fail` includes failures only.
- `--json-level=warn` includes failures and warnings.
- `--json-level=all` includes all reported checks.

Minimal failure JSON shape:

```json
{"status":"fail","first_failure":{"check":"docs","reason":"broken link in docs/INDEX.md","fix":"add the doc or update docs/INDEX.md"}}
```

JSON output shape should be documented per helper when that helper has JSON mode.

If JSON shape changes, update docs and tests in the same slice.

## Logs

Detailed logs may still be created, but compact output should not advertise logs on every successful run.

Default log root:

```text
${TMPDIR:-$HOME/.cache}/repo-automation-template
```

Print a log path only when:

- a failure or warning requires it;
- the user requested log output;
- the command's purpose is to create a log or evidence artifact;
- `--explain` is used.

Logs must not include secrets.

## Umbrella scripts

Umbrella scripts run multiple checks or child scripts.

Examples:

- `repo-automation/bin/run-tests --audit`
- `repo-automation/bin/run-tests --changed`
- `repo-automation/bin/repo-doctor --full`
- `repo-automation/bin/repo-doctor --quick`
- `repo-automation/bin/evidence-bundle --post-codex`
- `repo-automation/bin/evidence-bundle --include-repo-zip`
- `repo-automation/bin/repo-flow --watch --diagnose-on-fail`

All children pass:

```text
pass
```

First child failure:

```text
fail: run-tests: smoke:pr-create
excerpt: expected PR body file validation to block missing file
fix: inspect repo-automation/tests/contracts/pr-create.sh
```

Rules:

- Do not print one line per passing child.
- Stop UI output at the first actionable failure.
- Preserve full child details in logs, JSON, or `--explain` when useful.
- Keep umbrella success output as compact as any single script.

## Artifact-producing commands

Artifact-producing helpers should print path-only success when the artifact path is the result.

Examples:

- `repo-automation/bin/post-codex-packet`
- `repo-automation/bin/repo-zip`
- `repo-automation/bin/evidence-bundle`
- `repo-automation/bin/ci-log-dump`

Single artifact success:

```text
/storage/emulated/0/Documents/HeartloomVault/40_STAGING/repo-automation/repo-zip/repo-automation-template-review.zip
```

Multiple artifact success:

```text
bundle: /storage/emulated/0/Documents/HeartloomVault/40_STAGING/repo-automation/evidence-bundle/review.zip
packet: /storage/emulated/0/Documents/HeartloomVault/40_STAGING/repo-automation/post-codex/review.zip
```

Artifact warning:

```text
warn: skipped sensitive untracked file
file: .env
artifact: /storage/emulated/0/Documents/HeartloomVault/40_STAGING/repo-automation/post-codex/review.zip
```

Artifact failure:

```text
fail: zip creation failed
excerpt: permission denied writing output directory
fix: choose --out-dir=${TMPDIR:-$HOME/.cache}/repo-automation
```

Rules:

- Print the artifact path, not a paragraph.
- Print file count, size, checksum, or timestamp only when requested by `--explain`, JSON mode, or the helper's documented purpose.
- Never include ignored files, secrets, build artifacts, caches, `.git`, dependency folders, or generated binaries unless a helper explicitly documents a safe exception.

## Status and diagnostic commands

Status commands should output only the state that matters.

Clean status:

```text
clean
```

Dirty status:

```text
branch: output-contract-spec
changed:
- repo-automation/docs/output-modes.md
- docs/INDEX.md
```

No touched files:

```text
none
```

Touched files:

```text
repo-automation/docs/output-modes.md
docs/INDEX.md
```

No recent failure log:

```text
none
```

Failure log found:

```text
fail: latest run-tests failure
excerpt: shellcheck: repo-automation/bin/repo-flow: SC2086
log: ${TMPDIR:-$HOME/.cache}/repo-automation-template/run-tests-2026-05-14T215100.log
```

Rules:

- Do not mix unrelated diagnostics into status output.
- If the command is a diagnostic command, output only the relevant diagnostic data.
- If no data exists, print `none`, not an explanatory paragraph.

## CI commands

CI green:

```text
pass
```

CI red:

```text
fail: CI validate failed
run: 123456789
fix: repo-automation/bin/ci-log-dump --run-id=123456789
```

CI pending or timeout:

```text
wait: CI still pending after 600s
fix: rerun later or inspect GitHub Actions
```

Network or auth failure:

```text
fail: GitHub API unavailable
fix: retry before patching code
```

Rules:

- Network/auth failure is not CI failure.
- Do not tell the user to patch code unless CI failure evidence proves a code/doc/test problem.
- Prefer the smallest next command that retrieves the relevant evidence.

## Planning and dry-run commands

Safe no-op plan:

```text
plan: no changes
```

Plan with action:

```text
plan: create docs PR
branch: docs/output-contract
files: 2
```

Blocked plan:

```text
fail: blocked non-docs file
file: repo-automation/bin/run-tests
fix: use pr-create or narrow changed files
```

Rules:

- `--dry-run` and `--plan` should not perform writes.
- Output should show only the planned action, blocked reason, or next fix.
- Do not print full internal decision trees by default.

## Write/action commands

PR created or reused:

```text
https://github.com/i-schuyler/repo-automation-template/pull/53
```

PR merge completed:

```text
merged: #53
```

PR merge blocked:

```text
fail: PR checks not green
pr: #53
checks: red
fix: repo-automation/bin/pr-finish --watch --diagnose-on-fail --pr=53
```

Write blocked by dirty tree:

```text
fail: dirty worktree
fix: commit, stash, or revert changes first
```

Rules:

- Successful creation commands may output only the URL or resulting path.
- Successful destructive or irreversible commands should print the completed action.
- Blocked writes must print the blocker and smallest safe fix.

## Argument and flag errors

All helpers should use the same flag-error output shape.

Known value flag passed as `--flag value`:

```text
fail: flag format not accepted
flag: --pr
fix: use --pr=52
```

Unknown flag:

```text
fail: unknown flag
flag: --whatever
fix: run <script> --help
```

Missing value:

```text
fail: missing flag value
flag: --pr
fix: use --pr=<number|current|latest>
```

Empty value:

```text
fail: empty flag value
flag: --branch
fix: use --branch=<name>
```

Rules:

- `--flag value` is an error, not a warning, alias, fallback, or transition behavior.
- Prefer helper-specific fixes when a valid value set is known.
- Use the exact flag spelling in the `flag:` line.

## Help output

Help should remain compact and consistent.

Example:

```text
Usage: repo-automation/bin/run-tests [--summary] [--audit] [--changed] [--quiet] [--explain] [--json] [--help]
```

Rules:

- Help may include a compact options list.
- Help must document only accepted syntax.
- Help must not document `--flag value` for value flags.

## CI enforcement

Output contracts should be enforced in CI with exact stdout/stderr tests.

Required enforcement areas:

- default success prints only `pass` or the documented compact result;
- `--quiet` prints nothing on success;
- `--quiet` prints only first actionable failure on failure;
- warning-only output prints warning only;
- JSON modes print valid JSON only to stdout;
- umbrella scripts do not print child pass/status chatter;
- artifact-producing commands print path-only success where documented;
- known bad flag syntax produces the standard flag error;
- help output does not document stale flag shapes.

Prefer focused contract files under:

```text
repo-automation/tests/contracts/
```

## Examples by command type

Generic check scripts:

```text
repo-automation/bin/run-tests --changed --quiet
repo-automation/bin/repo-doctor --check=docs --quiet
repo-automation/tests/docs-check.sh
```

Expected clean output for default mode:

```text
pass
```

Expected clean output for quiet mode:

```text
```

Artifact scripts:

```text
repo-automation/bin/post-codex-packet --name=review
repo-automation/bin/evidence-bundle --pr=current --ci-failed
repo-automation/bin/repo-zip --name=review
```

Expected clean output:

```text
/path/to/artifact.zip
```

Status scripts:

```text
repo-automation/bin/status-packet
repo-automation/bin/touched-files --base=main --head=HEAD
```

Expected clean output may be:

```text
clean
```

or:

```text
none
```

## Non-goals

This contract does not require:

- verbose progress output;
- full local audit output on phone;
- child pass lines from umbrella scripts;
- log paths on every successful run;
- an `--agents` mode;
- dual human and JSON output in the same stream;
- accepting alternate value-flag syntax.
