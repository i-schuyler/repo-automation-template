# Repo Improvement Plan

Date: 2026-05-30

## Investigation Summary

- Primary language/tooling: Bash helper scripts with Python embedded for JSON/reporting, local smoke contracts, ShellCheck, and GitHub Actions CI.
- Public surface: `repo-automation/bin/*` helpers listed in `repo-automation/helper-metadata.json`, with behavior described by `repo-automation/docs/helper-contracts.md`, `repo-automation/docs/script-routing.md`, `repo-automation/docs/command-shape.md`, and per-helper docs.
- Core workflows: branch/preflight hygiene, PR creation/finish/merge flow, downstream install/update, diagnostics, CI evidence, review/repair artifact generation, and release/readiness checks.
- Test strategy: `repo-automation/bin/run-tests` orchestrates docs checks, version/manifest checks, ShellCheck when present, portability checks, and focused smoke contracts under `repo-automation/tests/contracts/`.
- CI gates: `.github/workflows/ci.yml` runs `git diff --check`, Bash syntax checks over `shellcheck-ci-parity --print-paths`, ShellCheck, `check-portability`, and `repo-automation/bin/run-tests`.
- Working tree was clean before edits (`git status --short` produced no output).

## Ranked Candidate Improvements

| Rank | Candidate | Evidence | Impact | Confidence | Scope control | Testability | Dependency value |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | Consolidate strict value-flag parsing | `repo-automation/docs/command-shape.md` requires common parser behavior where practical; `repo-automation/bin/contract-debt-report` reports 22 `parser-refactor` findings; `review-pack`, `repair-prompt`, `touched-files`, and `failure-log` duplicate `--flag value` / missing / empty handling around `repo_auto_flag_error`. | High | High | Medium | High | High |
| 2 | Split oversized smoke contract modules | `contract-debt-report` flags `repo-automation/tests/lib/contracts/artifacts.sh` at 2276 lines and `repo-automation/tests/contracts/repo-flow.sh` at 3776 lines. | High | High | Low | Medium | Medium |
| 3 | Fill missing JSON/quiet contract coverage | `contract-debt-report` reports 18 `contract-coverage` warnings across helpers with advertised JSON/quiet support. | Medium | High | Medium | High | Medium |
| 4 | Reduce very large helper scripts | `repo-doctor` (1314 lines), `slice-handoff` (1145), `run-tests` (1091), and `repo-automation-install` (960) are flagged as large/very large. | Medium | High | Low | Medium | Medium |
| 5 | Clean up small config validation drift | `repo-automation/lib/common.sh` lists `LOCAL_OVERRIDES_DOC` twice in `repo_auto_validate_required_config`. | Low | High | High | High | Low |
| 6 | Fix advisory docs coverage warnings | `contract-debt-report` says `prepare-release` and `slice-handoff` docs do not mention helper paths or usage examples. | Low | Medium | High | High | Low |

## Selected Improvement Arc

Implement a shared strict value-flag parser in `repo-automation/lib/common.sh` and migrate a controlled set of helpers that already have focused command-shape coverage:

- `repo-automation/bin/touched-files`
- `repo-automation/bin/failure-log`
- `repo-automation/bin/review-pack`
- `repo-automation/bin/repair-prompt`

This reduces duplicated parser branches while preserving the public CLI contract: value flags must use `--flag=value`; `--flag value`, missing values, empty values, and unknown flags keep the standard error shape.

## Implementation Plan

### Problem

Strict value-flag behavior is repeated across helpers even though the repo has a command-shape contract and a shared common library. The existing `repo_auto_parse_value_flag_equals` only handles equals-form assignment, leaving each caller to duplicate `--flag`, missing-value, and stale positional-value rejection logic.

### Evidence

- `repo-automation/docs/command-shape.md` says public helpers should share parser behavior through a common parser/helper where practical.
- `repo-automation/bin/contract-debt-report` reports 22 parser-refactor warnings.
- `repo-automation/tests/lib/contracts/parser-args.sh` already treats common parser behavior as a contract seam.
- `repo-automation/bin/review-pack` and `repo-automation/bin/repair-prompt` each define local `*_value_flag_error` functions with identical logic.
- `repo-automation/bin/touched-files` and `repo-automation/bin/failure-log` use the shared equals parser but duplicate non-equals rejection branches.

### Files Likely To Change

- `repo-automation/lib/common.sh`
- `repo-automation/docs/common-library.md`
- `repo-automation/bin/touched-files`
- `repo-automation/bin/failure-log`
- `repo-automation/bin/review-pack`
- `repo-automation/bin/repair-prompt`
- `repo-automation/bin/run-tests` (only if validation exposes related quiet/test harness noise)
- `repo-automation/tests/lib/contracts/parser-args.sh`
- `repo-automation/tests/lib/contracts/run-tests.sh` (only if validation exposes related quiet/test harness noise)
- `docs/INDEX.md`
- `docs/repo-improvement-plan.md`
- `repo-automation/docs/implementation-friction-ledger.md`

### Non-Goals

- Do not change accepted CLI syntax.
- Do not convert all public helpers in one slice.
- Do not rewrite command parsers into a new framework.
- Do not change JSON/output modes or helper workflows.
- Do not split large smoke modules in this slice.

### Acceptance Criteria

- Shared common-library parser handles equals-form assignment, empty values, missing values, and rejected positional values.
- Migrated helpers preserve documented error shape for `--flag=value`, `--flag=`, `--flag`, and `--flag value`.
- Focused contracts for parser seams and migrated helper surfaces pass.
- Bash syntax, ShellCheck parity paths, docs checks, version/manifest checks, and final practical validation pass.

### Verification Plan

- `repo-automation/tests/contracts/touched-files.sh --quiet`
- `repo-automation/tests/contracts/failure-log.sh --quiet`
- `repo-automation/tests/contracts/review-pack.sh --quiet`
- `repo-automation/tests/contracts/repair-prompt.sh --quiet`
- `bash -n` on touched shell files
- `repo-automation/tests/docs-check.sh --quiet`
- `repo-automation/tests/version-consistency.sh --quiet`
- `repo-automation/bin/managed-file-check --changed --quiet`
- `repo-automation/bin/check-portability --quiet`
- Strongest practical final validation: `repo-automation/bin/run-tests --audit --timeout=300 --quiet`

### Rollback / Recovery

Revert the helper migration in the four scripts first, leaving `repo_auto_parse_value_flag_strict` unused if necessary. If the common helper itself is faulty, revert `repo-automation/lib/common.sh`, `repo-automation/docs/common-library.md`, and the parser seam test together.

### Risks and Mitigations

- Risk: changed parser return codes could alter helper behavior. Mitigation: keep the same `repo_auto_flag_error` output and use existing command-shape contract tests.
- Risk: too broad a parser migration could hide unrelated regressions. Mitigation: migrate only four helpers with existing focused coverage.
- Risk: docs/index drift from adding this plan. Mitigation: update `docs/INDEX.md` and run docs checks.

### Handling New Issues During Implementation

- Blocking: fix immediately if parser behavior, syntax checks, or focused contracts fail.
- Related: fix immediately if within the selected parser arc and low-risk.
- Follow-up: document unrelated contract coverage, file-size, or docs-coverage debt here instead of expanding scope.

## Decisions Made During Implementation

- Added `repo_auto_parse_value_flag_strict` instead of changing the existing parser contract in place, so callers can migrate incrementally.
- Kept `repo_auto_parse_value_flag_equals` as a compatibility seam and delegated equals-form matching to the strict parser to avoid duplicate empty-value handling.
- Limited the first migration to `touched-files`, `failure-log`, `review-pack`, and `repair-prompt` because existing focused contracts cover their command-shape behavior.
- Fixed a related validation-harness noise issue when full quiet audit exposed a successful `run-tests` invocation printing a missing smoke capture `cat` error.

## New Issues Discovered While Implementing

- Follow-up: focused contract wrappers are not safe to run in parallel without isolated temp roots/stubs. Parallel quiet validation produced false failures for `review-pack` and `repair-prompt`; sequential quiet and explain reruns passed. Tracked in `repo-automation/docs/implementation-friction-ledger.md` as `focused-contract-parallel-temp-collision`.
- Fixed now: `run-tests --audit --quiet` could exit 0 while printing `cat: ...run-tests-smoke...log: No such file or directory` if a smoke subcheck removed the run-owned capture before log append. Added a guard and focused quiet regression coverage; tracked as `run-tests-smoke-capture-cleaned`.

## Final Verification Results

- Passed: `bash -n repo-automation/lib/common.sh repo-automation/bin/touched-files repo-automation/bin/failure-log repo-automation/bin/review-pack repo-automation/bin/repair-prompt repo-automation/bin/run-tests repo-automation/tests/lib/contracts/parser-args.sh repo-automation/tests/lib/contracts/run-tests.sh`
- Passed: `shellcheck -e SC2317 repo-automation/lib/common.sh repo-automation/bin/touched-files repo-automation/bin/failure-log repo-automation/bin/review-pack repo-automation/bin/repair-prompt repo-automation/bin/run-tests repo-automation/tests/lib/contracts/parser-args.sh repo-automation/tests/lib/contracts/run-tests.sh`
- Passed: `repo-automation/tests/contracts/touched-files.sh --quiet`
- Passed: `repo-automation/tests/contracts/failure-log.sh --quiet`
- Passed: `repo-automation/tests/contracts/review-pack.sh --quiet`
- Passed: `repo-automation/tests/contracts/repair-prompt.sh --quiet`
- Passed: `repo-automation/tests/contracts/run-tests.sh --quiet`
- Passed: `repo-automation/tests/docs-check.sh --quiet`
- Passed: `repo-automation/tests/version-consistency.sh --quiet`
- Passed: `repo-automation/bin/managed-file-check --changed --quiet`
- Passed with existing advisory warning: `repo-automation/bin/check-portability --quiet`
- Passed: `repo-automation/bin/contract-debt-report --quiet`; parser-refactor warnings dropped from 22 to 18 in the generated advisory report.
- Passed: `git diff --check`
- Passed: `repo-automation/bin/run-tests --audit --timeout=300 --quiet`
- Passed with expected dirty-worktree warning for this implementation: `repo-automation/bin/repo-doctor --full --timeout=300 --quiet`

## Follow-Up Backlog

1. Continue parser consolidation for `repo-automation-install`, `repo-automation-report-upstream`, `slice-run-dir`, and other helpers flagged by `contract-debt-report`.
2. Split `repo-automation/tests/lib/contracts/artifacts.sh` and `repo-automation/tests/contracts/repo-flow.sh` into smaller focused modules.
3. Add missing JSON/quiet contract coverage reported by `contract-debt-report`.
4. Decompose very large helpers (`repo-doctor`, `slice-handoff`, `run-tests`, `repo-automation-install`) around stable library seams.
5. Remove the duplicate `LOCAL_OVERRIDES_DOC` entry in `repo_auto_validate_required_config` when nearby config validation is touched.
6. Address low-risk docs coverage warnings for `prepare-release` and `slice-handoff`.
