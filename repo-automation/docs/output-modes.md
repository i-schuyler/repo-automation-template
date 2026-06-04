# Repo Automation Output Modes

Status: approved draft canon
Repo target: `repo-automation-template`
Intended repo path after approval: `repo-automation/docs/output-modes.md`
Purpose: define the repo-wide output-mode gates for human, quiet, JSON, and explain output.

This doc is the broader output-mode guide. The exit-code and stream contract lives in [Exit-Code / Stream Contract](exit-code-stream-contract.md).

## Core rules

- Default output is the least information helpful for a human.
- `--quiet` is the least information helpful for a machine or low-token agent caller.
- `--json` is detailed structured machine output.
- `--explain` is detailed step-by-step human/operator output.

Success should be quiet. Failure should be actionable. Diagnostics should be narrow.

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

## Approved gates

| Gate | Meaning | Success | Failure |
| --- | --- | --- | --- |
| Default human compact | minimal human-readable result | compact pass/result | compact fail plus next action |
| `--quiet` | low-token machine/agent-readable envelope | empty stdout, empty stderr, rc=0 | single minimal envelope on stderr |
| `--json` | detailed machine output | valid JSON only on stdout | valid JSON only on stdout |
| `--explain` | detailed human/operator output | progress plus final summary where supported | detailed actionable failure |

## Quiet Diagnostic Envelope v1

`--quiet` failures use a single minimal line-oriented envelope on stderr.
Stdout stays empty unless a helper explicitly documents a machine-primary result.

Required fields:

- `result=fail`
- `code=<stable-lowercase-dash-code>`
- `step=<stable-step-or-check>`
- `reason=<short-one-line-reason>`
- `fix=<short-next-action>`

Optional fields when needed:

- `path=<relevant-path>`
- `artifact=<relevant-artifact-path>`
- `log=<relevant-log-path>`
- `excerpt=<single-line-or-short-excerpt>`

Rules:

- Do not print multiple failures in quiet mode.
- Do not print child progress.
- Do not use JSON in quiet mode.
- Do not mix human prose into the envelope.

Example:

```text
result=fail
code=missing-required-heading
step=pr-body-check
reason=missing required heading: ## Scope
fix=use .github/pull_request_template.md or run repo-automation/bin/pr-body-check --print-template
```

## Default human compact failure

Default failure output stays compact and human-readable:

```text
fail: <step/check>: <reason>
excerpt: <smallest useful excerpt when needed>
artifact: <path only when useful>
fix: <next action>
```

Rules:

- Include only the next helpful artifact or log path.
- Keep child-script status out of umbrella output.
- Prefer one concise failure plus one fix.

## JSON

`--json` is detailed machine output, not “more detailed quiet.”

Rules:

- stdout must be valid JSON only.
- stderr may contain fatal wrapper errors only when JSON cannot be produced.
- Include `schema`, `result`, `code` on failure, `step`, `reason`, `fix`, and richer artifacts/children when relevant.
- JSON should carry the same core actionable facts as the compact result, without chatter.

## Explain

`--explain` is detailed human/operator output.

Rules:

- Show progress, summaries, and relevant artifact paths.
- May include multiple findings.
- Must stay actionable.
- Operator-facing helpers should end with a `===== FINAL SUMMARY =====` block when supported.

## Output-mode conflict rules

Unless a helper explicitly documents an exception, output modes are mutually exclusive.

- `--quiet --json` -> compact usage error
- `--quiet --explain` -> compact usage error
- `--json --explain` -> compact usage error

Do not guess precedence.

## Stream rules

- Default human success output goes to stdout.
- Artifact paths go to stdout when they are the next thing a human should inspect.
- Human warnings and failures go to stderr.
- `--json` writes valid JSON only to stdout.
- Non-JSON diagnostics must not mix into JSON stdout.
- `--help` writes usage to stdout.
- `--packet` is an action modifier, not an output mode.

## Umbrella and artifact rules

Umbrella scripts run multiple checks or child scripts.

Rules:

- Default: include an artifact/log path only when it is the next thing a human should inspect.
- Quiet: include at most one `artifact=` or `log=` unless multiple paths are required to classify the failure.
- JSON: include full artifact/log maps.
- Explain: include all relevant paths and summaries.
- Umbrella quiet failure should identify `result`, `code`, `step`, child when applicable, `reason`, one most relevant artifact/log if needed, and `fix`.

## Default human compact examples

Success:

```text
pass
```

Failure:

```text
fail: docs-check: broken link in docs/INDEX.md
excerpt: repo-automation/docs/command-shape.md not found
fix: add the doc or update docs/INDEX.md
```

## Contract-test wrappers

The contract-test wrappers and smoke harness use the same quiet-first posture as the public helpers.

- default success: `pass`
- `--quiet` success: empty stdout and stderr
- `--explain`: RUNNING/PASS/FAIL progress
- `--json`: valid JSON only on stdout
- focused wrappers derive `--help` usage from their own path and share the common wrapper runner in `repo-automation/tests/lib/smoke-common.sh`

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
