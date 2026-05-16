# Evidence Bundle

`repo-automation/bin/evidence-bundle` assembles one uploadable review bundle by coordinating the existing packet helpers and local repo state checks.

## Behavior

- includes `git status --short`
- includes touched-file evidence from `repo-automation/bin/touched-files`
- includes failure-log output when local logs are present
- leaves CI log capture off by default
- only calls `repo-automation/bin/ci-log-dump` when `--pr` is provided
- only calls `repo-automation/bin/post-codex-packet` when `--post-codex` is provided
- only calls `repo-automation/bin/repo-zip` when `--include-repo-zip` is provided
- defaults to `${REPO_AUTOMATION_OUTPUT_DIR:-${TMPDIR:-$HOME/.cache}/repo-automation}/evidence-bundle`
- writes a timestamped bundle directory with a `.zip` beside it
- keeps an index file under the output base

`--include-repo-zip` is opt-in because repo zips include untracked non-ignored files, so ignore secrets before sharing one.

## Options

- `--out-dir=<path>` overrides the output base
- `--label=<name>` adds a human-readable suffix to the bundle name
- `--pr=<number>` enables CI log capture for a specific PR
- `--post-codex` includes a post-Codex packet in the bundle
- `--include-repo-zip` includes a repository snapshot zip in the bundle
- `--lines=<lines>` sets the failure-log excerpt length

## Output

Success prints the bundle zip path.

## Example

    repo-automation/bin/evidence-bundle
    repo-automation/bin/evidence-bundle --label=review --post-codex --include-repo-zip
    repo-automation/bin/evidence-bundle --pr=123 --label=ci
