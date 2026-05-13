# Repo Zip

`repo-automation/bin/repo-zip` creates an uploadable snapshot zip of the current repository state.

## Behavior

- includes tracked files
- includes untracked non-ignored files from `git ls-files -co --exclude-standard`
- excludes `.git/`, `repo-automation-output/`, `post-codex/`, `ci-log-dump/`, and helper-generated zip/log artifacts
- untracked non-ignored files are included, so ignore secrets before sharing a zip
- defaults to `${REPO_AUTOMATION_OUTPUT_DIR:-${TMPDIR:-$HOME/.cache}/repo-automation}/repo-zip`
- writes a timestamped packet directory with `summary.txt` and `files.txt` beside the zip
- names the archive with the repo directory name and timestamp

## Options

- `--out-dir PATH` overrides the output base
- `--label NAME` adds a human-readable suffix to the packet and zip name

## Output

Human output reports:

- repo path
- branch
- `HEAD`
- packet dir
- zip path
- file count
- zip size
- zip modified time

## Example

    repo-automation/bin/repo-zip
    repo-automation/bin/repo-zip --out-dir /tmp/repo-automation-output --label review
