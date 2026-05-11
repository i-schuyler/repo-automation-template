# Version Modes

`repo-automation-template` uses several different version concepts. They are related, but they are not interchangeable.

## Automation Repo Release Version

- Source of truth: `VERSION`
- Means: the upstream `repo-automation-template` release version
- Owned by: repo automation maintainers
- Updated by: `repo-automation/bin/prepare-release`
- Used in: `README.md`, `CHANGELOG.md`, `docs/VERSIONING.md`, `docs/DECISIONS.md`, release metadata, and release-related checks

This is the only version `prepare-release` owns.

## Installed Automation Version/Ref

- Source of truth: downstream `.repo-automation.conf`
- Variable: `INSTALLED_VERSION_OR_REF`
- Means: the installed automation ref recorded in a downstream repo
- Owned by: the installer and the downstream repo that records provenance
- Updated by: `repo-automation/bin/repo-automation-install`
- Value shape: may be a tag, branch, commit, or other explicit installed ref

This is provenance for the installed automation copy. It is not a downstream product version.

## Starter-Template Version

- Source of truth: the reusable starter-template repo or template project itself, if it tracks one
- Means: the starter template's own version, separate from repo automation release versioning
- Owned by: the template project, not by `prepare-release`
- Updated by: the template project’s own release/version workflow

`repo-automation-template` may install starter-template files, but it does not own the starter template's version number.

## Downstream App/Product Version

- Source of truth: the downstream repo
- Means: the target app or product version in the downstream project
- Owned by: the downstream project
- Updated by: the downstream project’s own release/version workflow

Repo automation never owns or rewrites the downstream app/product version.

## Repo Automation Config Schema Version

- Source of truth: `REPO_AUTOMATION_CONF_VERSION`
- Means: the schema version of `.repo-automation.conf`
- Owned by: repo automation maintainers
- Updated by: a config-schema change, not by release/version helpers

`prepare-release` must not change this value. It exists to describe the config file shape, not the release version.

## Rules

- Use `REPO_AUTOMATION_VERSION` for the automation repo release version inside configs and docs.
- Use `INSTALLED_VERSION_OR_REF` only for downstream installed provenance.
- Do not use `INSTALLED_VERSION_OR_REF` to mean downstream product version.
- Do not use release helpers to update starter-template version fields.
- Do not use release helpers to update downstream app/product version fields.
- Use `--version=SEMVER` only for automation repo release version flows.
