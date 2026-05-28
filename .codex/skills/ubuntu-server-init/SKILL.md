---
name: ubuntu-server-init
description: "Initialize a fresh Ubuntu server or GPU container over SSH with practical defaults borrowed from dongzhuoyao/runpod_init: apt packages, GitHub SSH setup, workspace cache relocation, optional netrc, Codex/Kimi CLI installers, Conda init, Python venv setup, and optional Mihomo proxy deployment."
---

# ubuntu-server-init

Use this skill when the user wants to bootstrap a fresh Ubuntu remote machine, especially AutoDL/RunPod/GPU containers with persistent sandbox storage.

This skill borrows the operational pattern from `git@github.com:dongzhuoyao/runpod_init.git` at commit `050561641dddf8a55fd16488f00d3f14471efaee`, but makes it parameterized and safer for generic Ubuntu hosts.

It can also initialize the same Mihomo proxy setup used by `$deploy-ubuntu-mihomo` after the base server bootstrap.

## Sandbox selection

Before running initialization, identify the server sandbox/provider. If the user has not said it, ask which sandbox the server belongs to:

- `autodl`: data and cache under `/root/autodl-tmp`
- `runpod`: data and cache under `/workspace`
- `generic`: require an explicit `--workspace` path

For AutoDL, always save persistent data under `/root/autodl-tmp`.

## Defaults

- Sandbox: `autodl`
- Remote workspace for AutoDL: `/root/autodl-tmp`
- Remote workspace for RunPod: `/workspace`
- Packages: `tmux vim git curl ca-certificates openssh-client python3 python3-venv`
- Git key source on remote: `<workspace>/my_key`
- Git identity: `Tao <taohu620@gmail.com>`
- Cache relocation: `~/.cache -> /root/autodl-tmp/.cache`
- Optional `.netrc`: `/root/autodl-tmp/.netrc -> ~/.netrc`
- Optional Mihomo config: user-provided local Clash/Stash/Mihomo YAML path
- Optional Mihomo proxy targets: shell + apt by default

## Workflow

1. Confirm the SSH target and port.
2. Confirm whether the target is root or a sudo-capable user.
3. Choose which optional steps to apply:
   - GitHub SSH key setup
   - cache relocation
   - `.netrc` copy
   - Codex CLI install
   - Kimi Code CLI install
   - Conda init
   - venv creation or activation helper
   - Mihomo proxy deployment and proxy target setup
4. Run the bundled script.
5. Verify package availability, GitHub SSH behavior, cache symlink, and requested tools.

## Script

Use:

```bash
.codex/skills/ubuntu-server-init/scripts/ubuntu_server_init.sh \
  --host root@example.com \
  --ssh-port 22 \
  --sandbox autodl \
  --setup-git \
  --setup-cache \
  --copy-netrc
```

Common optional flags:

```bash
--init-conda
--conda-path /root/autodl-tmp/miniconda3/bin/conda
--create-venv /root/autodl-tmp/venv
--setup-mihomo
--mihomo-config /path/to/your/mihomo.yaml
--mihomo-binary ./mihomo-linux-amd64
--mihomo-apply-git
--mihomo-apply-docker
--install-codex
--install-kimi
--install-ai-clis        # install Codex + Kimi
--forward-agent          # use SSH agent forwarding, no key copy
--upload-key ~/.ssh/id_ed25519  # auto-upload local key to remote
--git-key-path /root/autodl-tmp/my_key
--git-name Tao
--git-email taohu620@gmail.com
--dry-run
```

`--install-codex` configures Codex with `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` after install. `--install-kimi` configures Kimi with `default_yolo = true` after install. `--install-ai-clis` applies both behaviors.

`--setup-mihomo` runs the sibling `.codex/skills/deploy-ubuntu-mihomo/scripts/deploy_ubuntu_mihomo.sh` after the base Ubuntu init. It applies shell + apt proxy settings by default. In this standalone `sandbox_init` repo, `--mihomo-config` is required so private proxy credentials are supplied explicitly by the caller and are not committed here. Add `--mihomo-apply-git` or `--mihomo-apply-docker` only when needed; Docker restart is side-effectful.

For GPU container conventions, read `references/gpu-container-notes.md`.
For security constraints around keys and credentials, read `references/security.md`.
For Kimi Code CLI invocation, read `references/kimi-code-cli.md`.

## Key handling options

To avoid manual `scp` of private keys, use one of these:

1. **SSH agent forwarding** (`--forward-agent`) — private key never leaves your local machine:
   ```bash
   ssh-add -l  # ensure your local agent has the key
   .codex/skills/ubuntu-server-init/scripts/ubuntu_server_init.sh \
     --host root@example.com \
     --sandbox autodl \
     --forward-agent \
     --setup-git
   ```

2. **Auto-upload** (`--upload-key`) — the script uploads your local key for you:
   ```bash
   .codex/skills/ubuntu-server-init/scripts/ubuntu_server_init.sh \
     --host root@example.com \
     --sandbox autodl \
     --upload-key ~/.ssh/id_ed25519 \
     --setup-git
   ```

## Verification

After the script runs, verify the requested setup:

```bash
ssh <target> 'tmux -V && git --version && python3 --version'
ssh <target> 'test -L ~/.cache && readlink ~/.cache'
ssh <target> 'ssh -T git@github.com || true'
ssh <target> 'codex --version || true; kimi --version || true'
ssh <target> 'grep -E "^(approval_policy|sandbox_mode)" ~/.codex/config.toml || true; grep -E "^default_yolo" ~/.kimi/config.toml || true'
ssh <target> 'systemctl is-active mihomo || true'
ssh <target> 'curl --proxy http://127.0.0.1:7890 -I --max-time 15 https://www.google.com || true'
```

If `--create-venv` was used:

```bash
ssh <target> 'source /root/autodl-tmp/venv/bin/activate && python --version && pip --version'
```

## Rollback

The script backs up overwritten files with `.bak.<timestamp>` where practical.

Common rollback commands:

```bash
ssh <target> 'rm -f ~/.ssh/config ~/.ssh/id_rsa ~/.netrc'
ssh <target> 'rm -f ~/.cache && test -e ~/.cache.bak.* && echo restore the desired ~/.cache.bak timestamp manually'
ssh <target> 'git config --global --unset user.name || true; git config --global --unset user.email || true'
```
