# Downstream Feedback

Downstream repos should separate shared automation bugs/features from repo-specific requests.

## Required Downstream Config

Installed config must include:

```sh
UPSTREAM_REPO_FULL_NAME="i-schuyler/repo-automation-template"
UPSTREAM_ISSUE_URL="https://github.com/i-schuyler/repo-automation-template/issues/new/choose"
INSTALLED_FROM="i-schuyler/repo-automation-template"
INSTALLED_VERSION_OR_REF="0.1.0"
INSTALLED_AT="YYYY-MM-DD"
LOCAL_OVERRIDES_DOC="repo-automation/docs/local-overrides.md"
```

`INSTALLED_VERSION_OR_REF` may be a tag, branch, commit, or other explicit installed automation ref.

## What To File Upstream

File bugs/features upstream when the issue is in shared automation behavior.

Keep local repo-specific requests local. Examples include repo-specific CI commands, docs paths, deployment paths, board config, application behavior, or private operational rules.

Redact secrets before filing. Do not paste tokens, private keys, passphrases, private env values, or raw logs containing secrets.

## Terminal Helper

```sh
repo-automation/bin/repo-automation-report-upstream --type=bug|feature
```

Implemented helper behavior:

- generate a local issue body preview before submission
- show the upstream repo target
- show issue type `bug` or `feature`
- show installed automation version/ref
- show whether local overrides are present
- warn users to redact secrets before submission
- prompt for confirmation before submission
- use GitHub CLI issue creation after preview approval
- stay terminal-only and not open a browser as the required path
- keep any future non-interactive mode behind explicit redaction safeguards

Issue bodies should include:

- downstream repo
- installed automation version/ref
- command run
- expected behavior
- actual behavior
- redacted logs
- whether local overrides are present

Issue forms in GitHub remain a fallback path when terminal helper usage is not possible.
