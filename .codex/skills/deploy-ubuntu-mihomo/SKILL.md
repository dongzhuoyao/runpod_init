---
name: deploy-ubuntu-mihomo
description: Deploy Mihomo/Clash.Meta on an Ubuntu remote machine using a Clash/Stash YAML config, install it as a systemd service or container-safe autostart fallback, configure shell/apt/git/Docker proxy settings, verify connectivity, and keep proxy/controller ports safely bound to localhost.
---

# deploy-ubuntu-mihomo

Use this skill when the user wants to apply their Stash/Clash proxy policy on an Ubuntu remote machine.

Default approach: run Mihomo directly on Ubuntu as a headless service and point local Ubuntu tools at `127.0.0.1:7890`. Use systemd when systemd is really active; otherwise install `/usr/local/bin/mihomo-autostart`, `/etc/profile.d/mihomo-autostart.sh`, and an `@reboot` crontab entry when `crontab` exists.

## Inputs to collect or infer

- Remote SSH target, such as `root@host` or `user@host`
- SSH port, if not `22`
- Config source:
  - project config such as `clash/clashteng.yaml`
  - project config such as `stash/stash_tenglong.clashmeta.yaml`
  - user-provided Clash/Stash/Mihomo YAML
- Which proxy targets to configure:
  - shell env
  - apt
  - git
  - Docker daemon
  - Docker CLI/container defaults

If the user has not chosen targets, install Mihomo and configure shell + apt only. Ask before changing Docker because it restarts the Docker daemon.

## Safety defaults

- Keep `mixed-port: 7890`.
- Keep `allow-lan: false`.
- Keep `external-controller: 127.0.0.1:9090`.
- Never expose `7890` or `9090` on `0.0.0.0` unless the user explicitly asks and accepts the risk.
- Back up existing remote files before overwriting.
- Do not store secrets in repo files or command logs.

Read `references/security.md` before enabling LAN access or authentication changes.

## Core workflow

1. Inspect the config before deployment.
   Confirm it has proxy definitions/providers, groups, and rules. If `mixed-port`, `allow-lan`, or `external-controller` are missing, add safe top-level defaults to the deployed copy, not necessarily the source file.
2. Run a dry-run if the target is unfamiliar.
3. Execute `scripts/deploy_ubuntu_mihomo.sh` from the skill directory.
4. Verify remote service health or fallback process health, startup mode, and proxy behavior.
5. Report changed files, enabled targets, verification evidence, and rollback commands.

## Script

Use the bundled script:

```bash
.codex/skills/deploy_ubuntu_mihomo/scripts/deploy_ubuntu_mihomo.sh \
  --host root@example.com \
  --config clash/clashteng.yaml \
  --apply-shell \
  --apply-apt
```

Common options:

```bash
--ssh-port 29571
--proxy-port 7890
--controller 127.0.0.1:9090
--mihomo-binary ./mihomo-linux-amd64
--apply-git
--apply-docker
--dry-run
```

Use `--mihomo-binary` when the remote cannot reach GitHub before the proxy is installed.

For target-specific config details, read `references/ubuntu-proxy-targets.md`.

## Verification

Run or confirm the script ran:

```bash
ssh <target> 'systemctl is-active mihomo'
ssh <target> 'pgrep -af "/usr/local/bin/mihomo -d /etc/mihomo" || true'
ssh <target> 'curl --proxy http://127.0.0.1:7890 -I --max-time 15 https://www.google.com'
ssh <target> "curl --noproxy '*' -sS --max-time 5 http://127.0.0.1:9090/proxies | head -c 200"
```

Optional checks:

```bash
ssh <target> 'sudo apt update'
ssh <target> 'sudo systemctl show --property=Environment docker'
ssh <target> 'docker pull hello-world'
```

## Rollback

The script writes timestamped backups beside changed files when a file already exists. To roll back, restore the relevant `.bak.<timestamp>` file and restart the affected service.

Minimum rollback:

```bash
ssh <target> 'sudo systemctl disable --now mihomo || true'
ssh <target> 'sudo pkill -f "/usr/local/bin/mihomo -d /etc/mihomo" || true'
ssh <target> 'sudo rm -f /etc/systemd/system/mihomo.service /usr/local/bin/mihomo-autostart /etc/profile.d/mihomo-autostart.sh /etc/profile.d/proxy.sh /etc/apt/apt.conf.d/95proxy'
ssh <target> 'sudo systemctl daemon-reload'
```
