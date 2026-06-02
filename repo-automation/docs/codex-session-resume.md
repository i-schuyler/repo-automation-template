# Codex Session Resume and Metadata

This note records public-safe observations from Codex CLI 0.135.0 probing. Treat the behavior below as observed, not guaranteed.

## Observed interactive and resume behavior

- `codex [OPTIONS] [PROMPT]` can start an interactive TUI session with an initial prompt.
- A prompt file can be used to start an interactive session by passing the file content as the prompt argument.
- `codex resume [OPTIONS] [SESSION_ID] [PROMPT]` resumes a previous session interactively.
- `codex resume --include-non-interactive <SESSION_ID>` can resume a non-interactive exec-created session in the TUI.
- `codex exec resume [OPTIONS] [SESSION_ID] [PROMPT]` resumes a previous session non-interactively.
- Resume accepts config/model-style overrides, including model and config overrides.
- Same-model resume with changed reasoning may be useful when intentional and recorded.
- Changing model type on resume should be avoided by default.

## Observed session metadata

Session files were JSONL event logs under the Codex sessions directory, using a date-partition plus session-id filename shape.

Observed top-level JSONL event envelope:

- `type`
- `timestamp`
- `payload`

Useful observed event types:

- `session_meta`
- `turn_context`
- `event_msg`
- `response_item`

Observed `session_meta` fields can include:

- session id
- cwd
- CLI version
- source or origin
- git branch
- git commit
- repository URL

Observed `turn_context` fields can include:

- model
- reasoning effort
- cwd
- related runtime settings

Observed token-count events can include:

- input tokens
- cached input tokens
- output tokens
- reasoning output tokens
- total tokens
- model context window
- plan type
- primary and secondary rate-limit window percentages

When both values are present, approximate remaining context can be derived as:

`model_context_window - total_tokens`

The rate-limit fields are useful operator telemetry and should inform future helper planning.

`sqlite3` was not available in the probe environment, but JSONL metadata was sufficient for the important findings.

## Operator ergonomics notes

- `codex completion` is shell autocomplete support and helps operator ergonomics, but it is not core repo automation behavior.
- `codex features list` is useful when a future workflow depends on optional or experimental behavior.

## Future helper direction

Do not implement these helpers yet; this section only records likely helper shape.

Preferred default behavior:

- keep `codex-run` deterministic and non-interactive by default
- do not make `slice-handoff` launch the interactive TUI as its default backend
- preserve deterministic slice-handoff boundaries

Future resumability should be artifact-backed:

- capture session id
- capture model, reasoning, cwd, and git metadata
- capture token, context, and rate-limit metadata
- write resume commands as artifacts
- print resume commands in blocker or re-entry contexts when useful

Possible future helper names:

- `codex-session-status`
- `codex-usage-status`
- `codex-resume-command`
- or one helper with subcommands or modes

For a consolidated future spec, see [Codex Status Helper Spec](codex-status.md).

A future usage helper should report:

- current session state
- context remaining
- token usage
- cached input tokens
- 5-hour limit percentage
- weekly limit percentage
- warning thresholds

A future pre-preflight step could warn when primary or weekly limits are near threshold and ask for explicit operator override.

Do not claim current helpers already implement session metadata scraping or rate-limit warnings unless they actually do.
