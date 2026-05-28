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

The script may install Codex or Kimi by using their upstream package/installer flows. Only enable those flags when the user explicitly wants those tools installed, and keep authentication material outside the repository.
