# Sandbox Initialization Scripts

Run from your Mac. One command sets up a fresh Ubuntu remote machine (AutoDL / RunPod / GPU container) with a working **Mihomo proxy**, GitHub SSH, dev tools, AI CLIs, and cache optimization.

## Primary Goal: Remote Proxy Setup

The main workflow initializes a remote machine **and** deploys a Mihomo/Clash proxy on it, so the remote has immediate outbound connectivity through your proxy.

### One-command setup

```bash
.codex/skills/ubuntu-server-init/scripts/ubuntu_server_init.sh \
  --host root@example.com \
  --sandbox autodl \
  --setup-git \
  --setup-cache \
  --setup-mihomo \
  --install-ai-clis
```

**What happens automatically:**
- Discovers your local SSH key (`~/.ssh/id_ed25519` -> `id_rsa` -> `id_ecdsa`)
- Discovers your local Mihomo/Clash config (`~/.config/clash.meta/*.yaml`)
- Uploads both to the remote
- Installs packages, configures Git, symlinks cache to persistent storage
- Optionally installs Codex and Kimi with approval-free/yolo defaults
- Deploys Mihomo with shell + apt proxy settings
- Uses systemd when available, or a container-safe autostart fallback when systemd is offline

**No manual `scp`. No copying paths. No committing secrets to the repo.**

### Options

| Flag | Behavior |
|------|----------|
| `--host root@ip` | SSH target (required) |
| `--sandbox autodl\|runpod\|generic` | Persistent storage preset |
| `--setup-git` | Configure Git + GitHub SSH |
| `--forward-agent` | Use SSH agent forwarding instead of uploading a key |
| `--upload-key ~/.ssh/id_rsa` | Upload a specific local key |
| `--setup-mihomo` | Deploy Mihomo proxy after base init |
| `--mihomo-config /path/to/config.yaml` | Override auto-discovered config |
| `--install-codex` | Install Codex and configure yolo defaults |
| `--install-kimi` | Install Kimi and configure `default_yolo = true` |
| `--install-ai-clis` | Install both Codex and Kimi |
| `--setup-cache` | Symlink `~/.cache` to persistent workspace |
| `--copy-netrc` | Copy `WORKSPACE/.netrc` to `~/.netrc` |
| `--init-conda` | Run `conda init bash` |
| `--create-venv /path` | Create a Python venv |
| `--dry-run` | Preview all actions without changing remote state |

### Standalone proxy deploy

If the base init is already done, deploy just the proxy:

```bash
.codex/skills/deploy-ubuntu-mihomo/scripts/deploy_ubuntu_mihomo.sh \
  --host root@example.com \
  --config /path/to/mihomo.yaml \
  --apply-shell \
  --apply-apt
```

Kimi Code CLI can also invoke these as skills:

```text
/skill:ubuntu-server-init initialize root@example.com for autodl and set up mihomo
```

## What the remote looks like after init

```
/root/
├── .ssh/
│   ├── id_rsa                         # your private key
│   └── config                         # GitHub SSH config
├── .cache -> /root/autodl-tmp/.cache  # symlink to persistent storage
└── .bashrc                            # shell environment

/root/autodl-tmp/                      # persistent workspace
├── .cache/                            # pip, huggingface, etc.
└── my_key                             # uploaded SSH key source backup

System:
├── /etc/mihomo/config.yaml             # deployed private proxy config
├── /etc/systemd/system/mihomo.service  # used when systemd is active
├── /usr/local/bin/mihomo-autostart     # fallback launcher for containers
├── /etc/profile.d/mihomo-autostart.sh  # login autostart hook
├── /etc/apt/apt.conf.d/95proxy         # apt proxy settings
└── tmux, vim, git, curl, python3       # base packages
```

Git identity:
```bash
git config --global user.name   # Tao
git config --global user.email  # taohu620@gmail.com
ssh -T git@github.com           # success
```

Proxy check:
```bash
curl --proxy http://127.0.0.1:7890 -I https://www.google.com
```

## Legacy root scripts

The original `init.sh`, `init_git.sh`, `init_cache.sh`, `init_conda.sh`, and `init_venv.sh` remain at the repository root for direct execution on the remote machine itself. The maintained SSH-based workflows live under `.codex/skills/` and should be preferred for new machines.

## Security

- **No secrets are committed to this repo.** Live proxy credentials and private keys live on your local machine and are uploaded at runtime.
- Private proxy credentials are supplied from an external `--mihomo-config` path or auto-discovered local config; they are never committed.
- An example config shape (with placeholders) is available at `examples/stash_tao.example.yaml`.
- Backups are created automatically for overwritten files (`*.bak.<timestamp>`).

## Features

- Zero-manual-copy SSH key discovery and upload
- Auto-discovery of local Mihomo/Clash configs
- Remote proxy deployment with systemd or container autostart fallback
- Optional Codex/Kimi installation with yolo defaults
- Cache relocation to persistent storage
- Dry-run mode for safe preview
- Error handling with `set -e`
