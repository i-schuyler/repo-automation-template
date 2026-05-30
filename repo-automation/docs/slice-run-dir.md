# Slice Run Dir

`slice-run-dir` creates and cleans up repo-owned run directories for the future `slice-handoff` execution path.

## Create

Create a marked run directory:

```sh
repo-automation/bin/slice-run-dir --create --branch=<name> [--root=<path>] [--json] [--quiet]
```

The default root is:

```sh
${TMPDIR:-$HOME/.cache}/repo-automation/slice-handoff-runs
```

Each created run dir gets a `.repo-automation-slice-run` marker with `schema=repo-automation-slice-run/v1`.

## Cleanup

Plan stale cleanup:

```sh
repo-automation/bin/slice-run-dir --cleanup-stale [--root=<path>] [--max-age-days=<n>] [--keep=<n>] [--preserve-path=<path>] [--json] [--quiet]
```

Apply stale cleanup:

```sh
repo-automation/bin/slice-run-dir --cleanup-stale [--root=<path>] [--max-age-days=<n>] [--keep=<n>] [--preserve-path=<path>] --apply [--json] [--quiet]
```

Cleanup deletes only marked repo-owned run dirs.
Unmarked dirs are never deleted.
The default mode is plan-only; `--apply` is required to delete anything.

`--json` is the machine-readable diagnostic mode.
`--explain` is not needed for Codex diagnostics.

## Safety

- scans only immediate child directories of the chosen root
- ignores symlinked candidates and symlinked or malformed markers
- preserves overlapping paths passed with `--preserve-path`
- never deletes the root itself
