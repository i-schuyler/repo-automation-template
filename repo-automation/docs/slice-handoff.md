# Slice Handoff

`slice-handoff` is a public-safe validated handoff runner for a bounded AI-assisted implementation slice.

## Dry-run mode

The non-executing mode is `--dry-run`.

`--dry-run` validates the handoff and may generate local artifacts, but it does not run Codex, create branches, commit, push, create PRs, watch CI, merge, delete branches, tag, release, publish, or write session metadata into tracked repo files.

Use `--out-dir=<path>` to write normalized local artifacts outside the repo root:

- `codex-prompt.md`
- `dry-run-preview.txt` non-executing public-safe preview of the future execution shape, including argv-style planned command shapes
- `slice-handoff-summary.txt`
- `review-request.txt`
- `pr-body.md` when `submit_mode: repo-flow-submit-all`

The out-dir must be outside the current repo root. Success prints the artifact paths unless `--quiet` is set.

`## PR Review Request` is recognized as a boundary and is emitted as `review-request.txt` when present or generated from public-safe defaults.

## Envelope and payloads

- envelope: branch, title, `codex_profile`, `commit_message`, submit mode, watch/timeout fields, and prompt preset identifiers
- payloads: Codex prompt, PR body, and PR-review request
- `slice-handoff` validates payload shape and configured policy, but it does not reinterpret strategy

## Public-safe state machine

`draft-handoff -> validate-envelope -> validate-pr-body -> validate-prompt-contract -> preflight -> codex-run -> codex-blocker OR submit-pr -> submit-blocker OR pr-ready-for-review`

## Deferred execution shape

Future execution mode is expected to:

- validate the handoff
- run preflight
- run a blocking Codex adapter/profile through `codex-run` (this slice is not wired to execute through it yet)
- classify Codex completion by child-process completion plus a recognizable final output contract
- validate PR body when submit is enabled
- explicitly submit through repo-flow only when the CLI invocation authorizes submit
- return blocker or PR-review handoff

## Timeout and profile contract

- no single global timeout
- `codex_timeout_seconds=0` means no hard Codex timeout
- submit/watch timeout is separate and may default to `900`
- detached or interactive-only Codex invocations are unsupported unless wrapped by an adapter that provides an exit code and final output file

Profile examples:

- `default`
- `lean`
- `medium`
- `high`
- `repair`
- `review`

## Safety rules

- no private prompt text or private workflow language in public docs
- generated logs/artifacts outside the repo root by default
- no tracked session metadata by default
- merge remains explicit and outside `slice-handoff`
