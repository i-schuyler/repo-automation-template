# Repo Automation Command Shape

Status: approved draft canon
Repo target: `repo-automation-template`
Intended repo path after approval: `repo-automation/docs/command-shape.md`
Purpose: define the newest command style for repo automation docs, operator handoffs, Codex prompts, and CI-safe examples.

This document replaces older command-shape language. The newest design is the only design.

## Core rule

Value flags must use `--flag=value`.

Do not accept `--flag value`.

Do not document `--flag value`.

Do not keep alternate accepted forms for convenience.

## Command principles

- Prefer the smallest command that answers the current question.
- Prefer targeted checks over umbrella checks.
- Prefer quiet output for agent/Codex checks.
- Prefer exact paths over broad globs when staging, committing, or reviewing changes.
- Prefer repo automation helpers over hand-written multi-command sequences when a helper exists.
- Do not include redundant dry runs, repeated status checks, or repeated diagnostics unless they add real evidence.
- Do not use destructive commands without a narrow, explicit purpose.

## Value flags

Canonical interface shape:

```text
--flag=value
```

Placeholder docs:

```text
--branch=<slice-branch>
--timeout=<seconds>
--out-dir=<path>
```

Runnable shell variables:

```text
--branch="$BRANCH"
--out-dir="$OUT_DIR"
```

Literal values with spaces:

```text
--title="Add quiet output contract"
--commit-message="docs: add quiet output contract"
```

Literal values without spaces:

```text
--timeout=120
--pr=current
--name=quiet-output-docs
```

Rules:

- `--flag=value` defines the CLI interface shape.
- Quotes are shell safety, not CLI shape.
- Quote the value portion when the value is a variable, path, sentence, glob-risk string, or may contain spaces.
- Do not imply quotes are part of the parser contract.
- Do not document or accept `--flag value`.

## Boolean flags

Boolean flags remain valueless.

Examples:

```text
--quiet
--explain
--dry-run
--merge
--delete-branch
--sync-main
--machine-json
```

Rules:

- Do not accept `--flag=true` unless the helper explicitly documents a non-boolean value flag.
- Do not accept `--flag false` as a negation pattern.
- Prefer explicit negative boolean flags when needed, such as `--no-repo-zip` or `--no-changed`.

## Rejected flag shapes

Known value flag passed as `--flag value`:

```text
repo-automation/bin/ci-log-dump --pr 52
```

Required output:

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
- All public helpers should use the same error wording.
- Parser contract tests should cover representative rejected forms.

## No alternate syntax layer

There is no alternate value-flag syntax layer.

The repo is early enough to make the newest design the only design.

Do not add parser branches whose only purpose is to support old value-flag shape.

Do not write docs that say a stale form is accepted.

Do not add tests that prove stale value-flag forms keep working.

Do add tests that prove stale value-flag forms fail with the standard flag error.

## Common value flags

Use these meanings consistently across helpers.

| Flag | Meaning |
| --- | --- |
| `--pr=<number|latest|current>` | PR selector |
| `--branch=<name>` | local branch name or branch selector, depending on helper |
| `--base=<branch>` | PR base branch |
| `--head=<branch>` | PR head branch |
| `--repo=<owner/repo>` | GitHub repo identifier |
| `--repo-root=<path>` | local repo root |
| `--source-root=<path>` | automation source root |
| `--source=<ci|local>` | repair-prompt evidence source |
| `--target-root=<path>` | downstream install target root |
| `--target=<review|codex>` | review-pack audience |
| `--target=codex` | repair-prompt audience |
| `--out-dir=<path>` | output directory override |
| `--evidence-file=<path>` | pre-generated evidence input |
| `--timeout=<seconds>` | maximum runtime for local check/watch operation |
| `--run-id=<id>` | GitHub Actions run ID |
| `--tail=<lines>` | number of log lines to include |
| `--lines=<lines>` | number of lines to show |
| `--name=<slug>` | artifact or slice slug |
| `--title=<text>` | PR or issue title |
| `--body-file=<path>` | file containing PR/issue body |
| `--commit-message=<text>` | commit message |
| `--json-level=<fail|warn|all>` | JSON detail level |

## Common output-shaping flags

Use these flags consistently.

| Flag | Use when |
| --- | --- |
| `--quiet` | a human-readable check should output nothing on success and only first failure on failure |
| `--explain` | a human needs detailed findings or log paths |
| `--json` | a helper exposes JSON mode |
| `--machine-json` | a helper exposes machine JSON mode |
| `--json-level=fail` | only failures are useful |
| `--json-level=warn` | failures and warnings are useful |
| `--json-level=all` | all check details are needed |

Do not add extra assistant-specific public modes unless `--quiet` and JSON modes cannot express a future need.

## Agent-preferred checks

For Codex and other agent-targeted checks, prefer minimal output:

```text
repo-automation/bin/run-tests --changed --quiet
repo-automation/bin/repo-doctor --check=docs --quiet
repo-automation/bin/repo-doctor --json --json-level=fail --check=docs
```

Use JSON only when structured parsing is needed. Otherwise, `--quiet` is the default low-token choice.

Avoid heavy/full local checks in constrained environments when targeted checks are available.

## Human diagnostic checks

For humans, start compact and escalate only when needed:

```text
repo-automation/bin/status-packet
repo-automation/bin/failure-log --latest --lines=80
repo-automation/bin/repo-doctor --check=docs --explain
```

Use `--explain` after a compact or quiet command has surfaced a failure.

## Repo start commands

Manual Termux command blocks that operate inside this repo should start with:

```bash
cd ~/projects/repo-automation-template
```

Use `mark` before commands when an operator needs the output pasted back. Use `recap` at the end of the same block.

Example:

```bash
cd ~/projects/repo-automation-template
mark
repo-automation/bin/status-packet
git status --short
recap
```

If the operator does not need terminal output back, omit `mark` and `recap`.

## Branch preflight shape

Before a Codex implementation slice, keep branch setup outside the Codex prompt.

Example:

```bash
cd ~/projects/repo-automation-template
BRANCH="replace-with-slice-branch"
repo-automation/bin/codex-slice-preflight --check-only --branch="$BRANCH" &&
repo-automation/bin/codex-slice-preflight --branch="$BRANCH"

git branch --show-current
git status --short
```

Use `mark` and `recap` when an operator needs to review the output:

```bash
cd ~/projects/repo-automation-template
mark
BRANCH="replace-with-slice-branch"
repo-automation/bin/codex-slice-preflight --check-only --branch="$BRANCH" &&
repo-automation/bin/codex-slice-preflight --branch="$BRANCH"

git branch --show-current
git status --short
recap
```

Do not put a `Start:` command section inside the Codex prompt for this repo.

## Codex prompt shape

For `repo-automation-template`, keep Codex prompts short and rely on repo `AGENTS.md` for standing constraints.

Default prompt shape:

```text
Task: <one sentence>
Goal: <what should change>
Scope: <files/areas and exclusions>
Checks allowed: <exact commands, or none>
Follow AGENTS.md.
```

Add task-specific output instructions only when the default `AGENTS.md` final-output contract is not enough.

Do not repeat `AGENTS.md` rules in prompts by default.

Do not reference conversation history, uploaded files, or “approved in chat” unless the needed content is pasted into the prompt or already exists in the repo.

## Post-Codex status reminder

After Codex runs, ask for a compact status recap outside the Codex prompt.

Example:

```bash
cd ~/projects/repo-automation-template
mark
git status --short
git diff --name-only
git ls-files --others --exclude-standard
repo-automation/bin/status-packet
repo-automation/bin/touched-files --base=main --head=HEAD
recap
```

Use a post-Codex packet when file-level review is needed:

```bash
cd ~/projects/repo-automation-template
mark
repo-automation/bin/post-codex-packet --name=review
recap
```

## Focused check shape

Use the narrowest check that proves the slice.

General changed check:

```bash
cd ~/projects/repo-automation-template
mark
repo-automation/bin/run-tests --changed --quiet

git status --short
recap
```

Docs-only check:

```bash
cd ~/projects/repo-automation-template
mark
repo-automation/tests/docs-check.sh
git diff --check
recap
```

One helper contract:

```bash
cd ~/projects/repo-automation-template
mark
repo-automation/tests/contracts/replace-helper-name.sh
git diff --check
recap
```

Shell syntax check for touched scripts:

```bash
cd ~/projects/repo-automation-template
mark
bash -n repo-automation/bin/replace-helper-name
recap
```

Avoid broad local checks on Android unless explicitly chosen:

```text
repo-automation/bin/run-tests --audit --timeout=200
repo-automation/bin/repo-doctor --full --timeout=200
```

## Commit shape

Commit explicit intended paths only.

```bash
cd ~/projects/repo-automation-template
mark
git add \
  path/to/first-file \
  path/to/second-file

git diff --cached --check &&
git diff --cached --name-only &&
git commit -m "type: concise commit message" &&
repo-automation/bin/repo-flow --watch --diagnose-on-fail

git status --short
recap
```

Rules:

- Do not blindly stage everything.
- Do not commit generated review packets, logs, caches, or build artifacts.
- Inspect staged names before commit.
- If no paths are staged, stop and inspect.

## CI diagnosis shape

Use the current PR number and request only the useful tail.

```bash
cd ~/projects/repo-automation-template
mark
PR="$(gh pr view --json number --jq .number)"
repo-automation/bin/ci-log-dump --pr="$PR" --tail=120
recap
```

Rules:

- Network/API/auth failure is not CI failure.
- Retry or inspect access failures before patching code.
- Patch only the smallest cause proven by latest CI evidence.

## Merge cleanup shape

Merge only after CI is green and the PR is ready.

```bash
cd ~/projects/repo-automation-template
mark
repo-automation/bin/pr-finish --merge --delete-branch --sync-main --pr=current

git branch --show-current
git status --short
recap
```

Rules:

- Do not merge from Codex by default.
- Do not delete branches unless the merge completed.
- Confirm branch and clean status after sync.

## Help output shape

Help must show only accepted syntax.

Example:

```text
Usage: repo-automation/bin/ci-log-dump [--pr=<number|current|latest>] [--run-id=<id>] [--tail=<lines>] [--quiet] [--explain] [--help]
```

Do not show:

```text
--pr NUMBER
--run-id ID
--tail LINES
```

## CI enforcement

Command shape should be enforced by CI.

Required enforcement areas:

- help output documents only `--flag=value` for value flags;
- known value flags reject `--flag value` with the standard error;
- unknown flags use the standard unknown-flag error;
- missing values use the standard missing-value error;
- empty values use the standard empty-value error;
- docs contain no stale `--flag value` examples;
- public helpers share parser behavior through a common parser/helper where practical;
- generated command examples use quotes for variables and spaced literals;
- generated command examples do not widen the accepted CLI surface.

Potential contract test files:

```text
repo-automation/tests/contracts/command-shape.sh
repo-automation/tests/contracts/output-modes.sh
```

## Non-goals

This contract does not support:

- short flags for new behavior;
- `--flag value` for value flags;
- mixed parser behavior across helpers;
- docs that show unaccepted syntax;
- quiet-success output that still prints progress;
- broad local checks in default phone workflows;
- Codex prompts that duplicate `AGENTS.md`.
