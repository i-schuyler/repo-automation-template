# Shared Bash Library

`scripts/lib/repo-automation-common.sh` is the shared Bash foundation for future repo automation scripts.

## Purpose

The library centralizes small behaviors that future scripts will need repeatedly:

- repo-root discovery
- config path discovery
- config loading
- safe state directory selection
- branch/provider/merge-mode validation
- required config validation
- conservative secret-marker scanning
- public-safe config summaries
- consistent info/warn/stop messaging

The shared library was introduced before workflow scripts and remains the common source of truth for script-level helpers.
Current slices now include initial workflow scaffolds for branch cleanup and codex preflight that source this library.

## Exported Functions

| Function | Purpose |
| --- | --- |
| `repo_auto_info` | Print an `INFO` message to stdout. |
| `repo_auto_warn` | Print a `WARN` message to stderr. |
| `repo_auto_stop` | Print a `STOP` message to stderr and return non-zero. |
| `repo_auto_require_command` | Require a command on `PATH`. |
| `repo_auto_repo_root` | Print the git repository root. |
| `repo_auto_config_path` | Print the repo-local `.repo-automation.conf` path. |
| `repo_auto_load_config` | Source the repo-local config after confirming it exists. |
| `repo_auto_state_dir` | Print the repo automation state directory under `${TMPDIR:-$HOME/.cache}`. |
| `repo_auto_is_positive_integer` | Validate positive integer values. |
| `repo_auto_validate_branch_name` | Reject unsafe branch names. |
| `repo_auto_validate_provider` | Allow `github`, `gitlab`, or `none`. |
| `repo_auto_validate_merge_mode` | Allow `squash`, `merge`, or `rebase`. |
| `repo_auto_validate_required_config` | Verify required config variables are present and valid. |
| `repo_auto_secret_scan_file` | Warn if a file contains likely secret markers. |
| `repo_auto_print_config_summary` | Print a public-safe config summary. |

## Stop Semantics

`repo_auto_stop` returns non-zero instead of using a literal `exit` command. That keeps the library sourceable and lets future scripts decide their own control flow.

## Usage Boundary

Future scripts should source this library and reuse its helpers instead of duplicating config parsing, validation, or output formatting.

Do not treat this file as a workflow implementation. It is only the shared shell layer for future slices.
