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
LOCAL_OVERRIDES_DOC="docs/repo-automation/local-overrides.md"
```

## What To File Upstream

File bugs/features upstream when the issue is in shared automation behavior.

Keep local repo-specific requests local. Examples include repo-specific CI commands, docs paths, deployment paths, board config, application behavior, or private operational rules.

Redact secrets before filing. Do not paste tokens, private keys, passphrases, private env values, or raw logs containing secrets.

## Future Terminal Helper

Future helper:

```sh
scripts/repo-automation-report-upstream --type bug|feature
```

The helper must complete from terminal using GitHub CLI issue creation and must not require opening a browser.

Issue bodies should include:

- downstream repo
- installed version/ref
- command run
- expected behavior
- actual behavior
- redacted logs
- whether local overrides are present
