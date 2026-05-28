#!/usr/bin/env bash
set -euo pipefail

HOST=""
SSH_PORT="22"
CONFIG=""
PROXY_PORT="7890"
CONTROLLER="127.0.0.1:9090"
MIHOMO_BINARY=""
APPLY_SHELL=0
APPLY_APT=0
APPLY_GIT=0
APPLY_DOCKER=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  deploy_ubuntu_mihomo.sh --host user@host --config config.yaml [options]

Options:
  --ssh-port PORT       SSH port, default 22
  --proxy-port PORT     Mihomo mixed-port, default 7890
  --controller ADDR     External controller, default 127.0.0.1:9090
  --mihomo-binary PATH  Local Mihomo binary to upload instead of remote GitHub download
  --apply-shell         Write /etc/profile.d/proxy.sh
  --apply-apt           Write /etc/apt/apt.conf.d/95proxy
  --apply-git           Set global git http.proxy and https.proxy for the SSH user
  --apply-docker        Configure Docker daemon and Docker CLI proxy, restarting Docker
  --dry-run             Print actions without changing the remote
  -h, --help            Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:?}"; shift 2 ;;
    --ssh-port) SSH_PORT="${2:?}"; shift 2 ;;
    --config) CONFIG="${2:?}"; shift 2 ;;
    --proxy-port) PROXY_PORT="${2:?}"; shift 2 ;;
    --controller) CONTROLLER="${2:?}"; shift 2 ;;
    --mihomo-binary) MIHOMO_BINARY="${2:?}"; shift 2 ;;
    --apply-shell) APPLY_SHELL=1; shift ;;
    --apply-apt) APPLY_APT=1; shift ;;
    --apply-git) APPLY_GIT=1; shift ;;
    --apply-docker) APPLY_DOCKER=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$HOST" || -z "$CONFIG" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "Config not found: $CONFIG" >&2
  exit 1
fi

if [[ -n "$MIHOMO_BINARY" && ! -f "$MIHOMO_BINARY" ]]; then
  echo "Mihomo binary not found: $MIHOMO_BINARY" >&2
  exit 1
fi

ssh_cmd=(ssh -p "$SSH_PORT" -o BatchMode=yes -o ConnectTimeout=15 "$HOST")
scp_cmd=(scp -P "$SSH_PORT")

run_remote() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run ssh %s] %s\n' "$HOST" "$*"
  else
    "${ssh_cmd[@]}" "$@"
  fi
}

copy_to_remote() {
  local src="$1"
  local dst="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run scp] %s -> %s:%s\n' "$src" "$HOST" "$dst"
  else
    "${scp_cmd[@]}" "$src" "$HOST:$dst"
  fi
}

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

DEPLOY_CONFIG="$tmpdir/config.yaml"
python3 - "$CONFIG" "$DEPLOY_CONFIG" "$PROXY_PORT" "$CONTROLLER" <<'PY'
import pathlib
import re
import sys

src, dst, proxy_port, controller = sys.argv[1:]
text = pathlib.Path(src).read_text(encoding="utf-8")

required_patterns = {
    "proxy definitions/providers": r"(?m)^(proxies|proxy-providers):",
    "proxy-groups": r"(?m)^proxy-groups:",
    "rules": r"(?m)^rules:",
}
missing = [name for name, pattern in required_patterns.items() if not re.search(pattern, text)]
if missing:
    raise SystemExit("Config is missing: " + ", ".join(missing))

prepend = []
if not re.search(r"(?m)^mixed-port:", text):
    prepend.append(f"mixed-port: {proxy_port}")
if not re.search(r"(?m)^allow-lan:", text):
    prepend.append("allow-lan: false")
if not re.search(r"(?m)^external-controller:", text):
    prepend.append(f"external-controller: {controller}")

if re.search(r"(?m)^allow-lan:\s*true\b", text):
    raise SystemExit("Refusing to deploy config with allow-lan: true by default")
if re.search(r"(?m)^external-controller:\s*(0\.0\.0\.0|\*):", text):
    raise SystemExit("Refusing to deploy public external-controller")

out = ("\n".join(prepend) + "\n\n" if prepend else "") + text
pathlib.Path(dst).write_text(out, encoding="utf-8")
PY

remote_tmp="/tmp/mihomo-config.$$.$RANDOM.yaml"
remote_binary=""
copy_to_remote "$DEPLOY_CONFIG" "$remote_tmp"

if [[ -n "$MIHOMO_BINARY" ]]; then
  remote_binary="/tmp/mihomo-binary.$$.$RANDOM"
  copy_to_remote "$MIHOMO_BINARY" "$remote_binary"
fi

remote_script="$tmpdir/remote-install.sh"
cat > "$remote_script" <<'REMOTE'
#!/usr/bin/env bash
set -euo pipefail

remote_tmp="${1:?}"
proxy_port="${2:?}"
controller="${3:?}"
apply_shell="${4:?}"
apply_apt="${5:?}"
apply_git="${6:?}"
apply_docker="${7:?}"
remote_binary="${8:-}"

stamp="$(date +%Y%m%d%H%M%S)"
no_proxy_value="localhost,127.0.0.1,::1,169.254.169.254,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

sudo_cmd() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

backup_file() {
  local path="$1"
  if [[ -e "$path" ]]; then
    sudo_cmd cp -a "$path" "$path.bak.$stamp"
    echo "backup: $path.bak.$stamp"
  fi
}

systemd_ready() {
  [[ -d /run/systemd/system ]] && need_cmd systemctl && [[ "$(systemctl is-system-running 2>/dev/null || true)" != "offline" ]]
}

if [[ ! -f /etc/os-release ]]; then
  echo "Cannot identify remote OS: /etc/os-release missing" >&2
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *"debian"* ]]; then
  echo "Warning: expected Ubuntu/Debian-like OS, got ID=${ID:-unknown}" >&2
fi

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) mihomo_arch="amd64" ;;
  aarch64|arm64) mihomo_arch="arm64" ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac

if ! need_cmd curl || ! need_cmd python3 || ! need_cmd gzip; then
  sudo_cmd apt-get update
  sudo_cmd apt-get install -y curl ca-certificates tar gzip python3
fi

if ! need_cmd mihomo; then
  if [[ -n "$remote_binary" && -f "$remote_binary" ]]; then
    chmod +x "$remote_binary"
    sudo_cmd install -m 0755 "$remote_binary" /usr/local/bin/mihomo
    rm -f "$remote_binary"
  else
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    api="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
    url="$(curl -fsSL "$api" | python3 -c '
import json, re, sys
data=json.load(sys.stdin)
arch=sys.argv[1]
pattern=re.compile(r"linux-" + re.escape(arch) + r".*\\.gz$")
for asset in data.get("assets", []):
    name=asset.get("name", "")
    if pattern.search(name) and "compatible" not in name:
        print(asset["browser_download_url"])
        break
' "$mihomo_arch")"
  if [[ -z "$url" ]]; then
    echo "Could not find Mihomo linux-$mihomo_arch release asset" >&2
    exit 1
  fi
    curl -fL "$url" -o "$tmpdir/mihomo.gz"
    gzip -d "$tmpdir/mihomo.gz"
    chmod +x "$tmpdir/mihomo"
    sudo_cmd install -m 0755 "$tmpdir/mihomo" /usr/local/bin/mihomo
  fi
fi

sudo_cmd mkdir -p /etc/mihomo
backup_file /etc/mihomo/config.yaml
sudo_cmd install -m 0644 "$remote_tmp" /etc/mihomo/config.yaml
sudo_cmd rm -f "$remote_tmp"

backup_file /etc/systemd/system/mihomo.service
cat >/tmp/mihomo.service.$$ <<'EOF'
[Unit]
Description=mihomo proxy daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Restart=always
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
sudo_cmd install -m 0644 /tmp/mihomo.service.$$ /etc/systemd/system/mihomo.service
rm -f /tmp/mihomo.service.$$

cat >/tmp/mihomo-autostart.$$ <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if pgrep -f '^/usr/local/bin/mihomo -d /etc/mihomo$' >/dev/null 2>&1; then
  exit 0
fi

mkdir -p /var/log
nohup /usr/local/bin/mihomo -d /etc/mihomo >>/var/log/mihomo.log 2>&1 &
EOF
sudo_cmd install -m 0755 /tmp/mihomo-autostart.$$ /usr/local/bin/mihomo-autostart
rm -f /tmp/mihomo-autostart.$$

cat >/tmp/mihomo-autostart-profile.$$ <<'EOF'
# Auto-start Mihomo on container login when systemd is unavailable.
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && [ "$(systemctl is-system-running 2>/dev/null || true)" != "offline" ]; then
  :
elif command -v /usr/local/bin/mihomo-autostart >/dev/null 2>&1; then
  /usr/local/bin/mihomo-autostart >/dev/null 2>&1 || true
fi
EOF
sudo_cmd install -m 0644 /tmp/mihomo-autostart-profile.$$ /etc/profile.d/mihomo-autostart.sh
rm -f /tmp/mihomo-autostart-profile.$$

if need_cmd crontab; then
  current_cron="$(mktemp)"
  crontab -l >"$current_cron" 2>/dev/null || true
  if ! grep -Fq '/usr/local/bin/mihomo-autostart' "$current_cron"; then
    printf '%s\n' '@reboot /usr/local/bin/mihomo-autostart >/dev/null 2>&1' >> "$current_cron"
    crontab "$current_cron"
  fi
  rm -f "$current_cron"
fi

if [[ "$apply_shell" == "1" ]]; then
  backup_file /etc/profile.d/proxy.sh
  cat >/tmp/proxy.sh.$$ <<EOF
export http_proxy="http://127.0.0.1:${proxy_port}"
export https_proxy="http://127.0.0.1:${proxy_port}"
export all_proxy="socks5h://127.0.0.1:${proxy_port}"
export HTTP_PROXY="\$http_proxy"
export HTTPS_PROXY="\$https_proxy"
export ALL_PROXY="\$all_proxy"
export no_proxy="${no_proxy_value}"
export NO_PROXY="\$no_proxy"
EOF
  sudo_cmd install -m 0644 /tmp/proxy.sh.$$ /etc/profile.d/proxy.sh
  rm -f /tmp/proxy.sh.$$
fi

if [[ "$apply_apt" == "1" ]]; then
  sudo_cmd mkdir -p /etc/apt/apt.conf.d
  backup_file /etc/apt/apt.conf.d/95proxy
  cat >/tmp/95proxy.$$ <<EOF
Acquire::http::Proxy "http://127.0.0.1:${proxy_port}/";
Acquire::https::Proxy "http://127.0.0.1:${proxy_port}/";
EOF
  sudo_cmd install -m 0644 /tmp/95proxy.$$ /etc/apt/apt.conf.d/95proxy
  rm -f /tmp/95proxy.$$
fi

if [[ "$apply_git" == "1" ]]; then
  git config --global http.proxy "http://127.0.0.1:${proxy_port}"
  git config --global https.proxy "http://127.0.0.1:${proxy_port}"
fi

if [[ "$apply_docker" == "1" ]]; then
  if need_cmd docker || (systemd_ready && systemctl list-unit-files docker.service >/dev/null 2>&1); then
    sudo_cmd mkdir -p /etc/systemd/system/docker.service.d
    backup_file /etc/systemd/system/docker.service.d/http-proxy.conf
    cat >/tmp/docker-http-proxy.conf.$$ <<EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:${proxy_port}"
Environment="HTTPS_PROXY=http://127.0.0.1:${proxy_port}"
Environment="NO_PROXY=${no_proxy_value}"
EOF
    sudo_cmd install -m 0644 /tmp/docker-http-proxy.conf.$$ /etc/systemd/system/docker.service.d/http-proxy.conf
    rm -f /tmp/docker-http-proxy.conf.$$
    mkdir -p "$HOME/.docker"
    backup_file "$HOME/.docker/config.json"
    cat >"$HOME/.docker/config.json" <<EOF
{
  "proxies": {
    "default": {
      "httpProxy": "http://127.0.0.1:${proxy_port}",
      "httpsProxy": "http://127.0.0.1:${proxy_port}",
      "noProxy": "${no_proxy_value}"
    }
  }
}
EOF
  else
    echo "Docker not found; skipping Docker proxy config"
  fi
fi

if systemd_ready; then
  sudo_cmd systemctl daemon-reload
  sudo_cmd systemctl enable --now mihomo
  sudo_cmd systemctl restart mihomo
  startup_mode="systemd"
else
  pkill -f '/usr/local/bin/mihomo -d /etc/mihomo' >/dev/null 2>&1 || true
  sudo_cmd /usr/local/bin/mihomo-autostart
  startup_mode="profile-autostart"
fi

controller_ready=0
for _ in $(seq 1 20); do
  if curl --noproxy '*' -fsS --max-time 2 "http://${controller}/proxies" >/tmp/mihomo-proxies.json; then
    controller_ready=1
    break
  fi
  sleep 1
done
if [[ "$controller_ready" != "1" ]]; then
  echo "Mihomo controller did not become ready: http://${controller}/proxies" >&2
  tail -50 /var/log/mihomo.log 2>/dev/null || true
  exit 1
fi

if [[ "$apply_docker" == "1" ]] && systemd_ready && systemctl list-unit-files docker.service >/dev/null 2>&1; then
  sudo_cmd systemctl daemon-reload
  sudo_cmd systemctl restart docker || echo "Warning: docker restart failed" >&2
fi

if systemd_ready; then
  echo "mihomo_status=$(systemctl is-active mihomo)"
else
  pgrep -af '^/usr/local/bin/mihomo -d /etc/mihomo$'
  echo "mihomo_status=running"
fi
echo "mihomo_startup_mode=${startup_mode}"
echo "controller_ok=1 bytes=$(wc -c </tmp/mihomo-proxies.json)"
curl --proxy "http://127.0.0.1:${proxy_port}" -I --max-time 20 http://www.gstatic.com/generate_204 | sed -n '1,5p'
REMOTE

copy_to_remote "$remote_script" "/tmp/deploy-mihomo-remote.sh"
run_remote "bash /tmp/deploy-mihomo-remote.sh '$remote_tmp' '$PROXY_PORT' '$CONTROLLER' '$APPLY_SHELL' '$APPLY_APT' '$APPLY_GIT' '$APPLY_DOCKER' '$remote_binary'; status=\$?; rm -f /tmp/deploy-mihomo-remote.sh; exit \$status"

cat <<EOF

Deploy finished.
Remote: $HOST
Proxy: http://127.0.0.1:${PROXY_PORT}
Controller: http://${CONTROLLER}
Config source: $CONFIG
EOF
