# VPS Codex Host Readiness

Use this as a minimum gate list before treating a small Ubuntu VPS as a remote Codex execution host for this repo.

The host is repo-only. It is not a vault sync peer and should not be documented with private hostnames, IPs, usernames, tokens, or backup details.

Minimum gates:

- SSH access works and a durable `tmux` session can be reached after login.
- The GitHub SSH alias used by this repo works for fetch/push authentication.
- `gh auth status` succeeds for the account that will operate on the repo.
- The repo is cloned on the host and the working tree is clean before a Codex session starts.
- Required tooling is already installed and usable: Node.js, `npm`, and Codex.
- Swap is active so the host can absorb memory pressure from local execution.
- Available disk headroom has been checked before use.
- Broad or full validation does not move to the VPS by default. GitHub Actions remains the authoritative system for repo-wide validation.

Practical checks:

- Reach the host with SSH, start or attach `tmux`, and confirm the shell is stable.
- Verify the repo remote uses the expected GitHub SSH alias and that Git operations succeed.
- Run `gh auth status` and confirm the session is authenticated.
- Confirm the clone is the intended repo checkout and is not already dirty.
- Confirm `node --version`, `npm --version`, and `codex --version` succeed.
- Confirm swap is enabled and disk usage leaves enough free space for the working tree and local artifacts.

If any gate fails, treat the host as not ready and fix that prerequisite before using it for repo work.
