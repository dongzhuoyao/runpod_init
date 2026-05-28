# Security

SSH keys and credential files are sensitive.

Rules:

- Never print private key contents.
- Never commit copied keys, `.netrc`, tokens, or generated credentials.
- Keep `~/.ssh` at mode `700`.
- Keep private keys and `~/.ssh/config` at mode `600`.
- Keep `.netrc` at mode `600`.
- Use `StrictHostKeyChecking accept-new` for first-time GitHub setup rather than disabling host key checks.
- Prefer a deploy key or least-privilege GitHub key for remote containers.

The script may install Claude CLI or OpenCode by piping remote installer scripts from their official URLs. Only enable those flags when the user explicitly wants those tools installed.

