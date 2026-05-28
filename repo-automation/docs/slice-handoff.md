# Slice Handoff

`slice-handoff` is a planned public-safe validated handoff runner for a bounded AI-assisted implementation slice.

## Planned mode

The first implementation mode is `--plan-only`.

`--plan-only` validates the handoff and may generate local artifacts, but it does not run Codex, create branches, commit, push, create PRs, watch CI, merge, delete branches, tag, release, publish, or write session metadata into tracked repo files.

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
- run a blocking Codex adapter/profile
- classify Codex completion by child-process completion plus final output file
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

- no private prompt text in public docs
- generated logs/artifacts outside the repo root by default
- no tracked session metadata by default
- merge remains explicit and outside `slice-handoff`
