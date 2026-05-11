# Report Upstream

`repo-automation/bin/repo-automation-report-upstream` prepares upstream automation bug/feature reports from terminal with preview and redaction safeguards.

Default behavior is preview/plan-only. No issue is created unless `--submit` is explicitly passed.

## Core behavior

- `--type bug` and `--type feature` are supported.
- A title is required.
- A local issue-body preview is always generated before submission.
- Preview defaults to `${TMPDIR:-$HOME/.cache}/repo-automation-template/report-upstream-preview.md` unless `--preview-file` is provided.
- `--dry-run` never submits, even when `--submit` is passed.
- `--submit` without `--yes` prompts for explicit confirmation after preview.
- `--submit --yes` supports non-interactive submission when required fields exist and secret scan passes.

## Installed context

Issue body preview includes:

- upstream repo target
- installed automation version/ref
- installed date
- local overrides doc
- local overrides presence
- current repo root name
- command/expected/actual (bug)
- use-case/proposed/why-upstream (feature)
- redaction checklist

## Redaction boundary

If `--logs-file` or `--body-file` is provided, a conservative secret scan runs before use.

Submission stops when likely secret markers are found. The helper does not print matching secret content.

The helper stays terminal-only and does not require opening a browser.

## JSON contract

With `--json`, stdout is valid JSON only and human logs go to stderr.

JSON includes:

- `mode`
- `type`
- `title`
- `upstream_repo`
- `labels`
- `preview_file`
- `submitted`
- `issue_number`
- `issue_url`
- `redaction_scan`
- `installed_version_or_ref`
- `local_overrides_doc`
- `action_taken`
- `stop_reason`

Usage examples:

    repo-automation/bin/repo-automation-report-upstream --type=bug --title="Branch cleanup classification issue" --command="repo-automation/bin/branch-cleanup --plan" --expected="classifies merged branch as candidate" --actual="branch marked ambiguous" --dry-run
    repo-automation/bin/repo-automation-report-upstream --type=feature --title="Add provider compatibility matrix docs" --use-case="cross-provider setup churn" --proposed="new docs section and validation notes" --why-upstream="shared behavior across downstream installs" --dry-run --json
    repo-automation/bin/repo-automation-report-upstream --type=bug --title="Preflight divergence check mismatch" --command="repo-automation/bin/codex-slice-preflight --branch=feature/x" --expected="clean divergence summary" --actual="unexpected stop with stale ref" --logs-file=./redacted.log --submit
