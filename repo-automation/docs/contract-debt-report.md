# Contract Debt Report

`repo-automation/bin/contract-debt-report` is an advisory, metadata-driven report helper for maintainability debt and contract drift.

It scans public helper metadata, the managed-file manifest, helper docs, helper contract tests, and tracked repo files. Debt findings are warnings only; the command exits nonzero only for operational errors.

## Outputs

- `contract-debt-report.md`
- `contract-debt-report.json`

Default output prints the markdown report path only. `--quiet` stays silent on success. `--explain` prints compact counts, status, report paths, and top categories. `--json` writes valid JSON to stdout and still writes both report files.

## Thresholds

- `script_large_lines=500`
- `script_very_large_lines=900`
- `test_large_lines=900`
- `test_very_large_lines=1500`
- `doc_large_lines=450`
- `doc_very_large_lines=900`
- `repeated_flag_parser_branches=8`
- `max_findings_per_category=20`

## Example

```sh
repo-automation/bin/contract-debt-report
repo-automation/bin/contract-debt-report --json
repo-automation/bin/contract-debt-report --out-dir=/path/to/report --explain
```

## Advisory Scope

This helper is separate from repo health, docs enforcement, portability drift, and CI artifact assembly. It is intended to surface low-noise maintainability debt without blocking CI.
