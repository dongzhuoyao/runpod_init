#!/usr/bin/env bash
set -euo pipefail

HOST=""
SSH_PORT="22"
SANDBOX="autodl"
WORKSPACE=""
WORKSPACE_SET=0
PACKAGES="tmux vim git git-lfs curl ca-certificates openssh-client python3 python3-venv"
SETUP_GIT=0
SETUP_CACHE=0
COPY_NETRC=0
INIT_CONDA=0
CREATE_VENV=""
INSTALL_CODEX=0
INSTALL_KIMI=0
SETUP_MIHOMO=0
MIHOMO_CONFIG=""
MIHOMO_BINARY=""
MIHOMO_APPLY_GIT=0
MIHOMO_APPLY_DOCKER=0
GIT_KEY_PATH=""
GIT_NAME="Tao"
GIT_EMAIL="taohu620@gmail.com"
CONDA_PATH=""
FORWARD_AGENT=0
UPLOAD_KEY=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  ubuntu_server_init.sh --host user@host [options]

Options:
  --ssh-port PORT          SSH port, default 22
  --sandbox NAME           Sandbox/provider: autodl, runpod, or generic. Default autodl
  --workspace PATH         Persistent workspace path. Defaults by sandbox
  --packages "PKGS"        Apt packages to install
  --setup-git              Configure GitHub SSH using a remote key file
  --git-key-path PATH      Remote private key path, default WORKSPACE/my_key
  --forward-agent          Use SSH agent forwarding instead of copying a remote key
  --upload-key PATH        Local private key path to auto-upload to WORKSPACE/my_key
  --git-name NAME          Git user.name, default Tao
  --git-email EMAIL        Git user.email, default taohu620@gmail.com
  --setup-cache            Link ~/.cache to WORKSPACE/.cache
  --copy-netrc             Copy WORKSPACE/.netrc to ~/.netrc when present
  --install-codex          Install OpenAI Codex CLI (Node.js + npm global)
  --install-kimi           Install Kimi Code CLI using the official installer
  --install-ai-clis        Install both Codex and Kimi Code CLIs
  --init-conda             Run conda init bash if conda exists
  --conda-path PATH        Conda binary path, default WORKSPACE/miniconda3/bin/conda
  --create-venv PATH       Create a Python venv if it does not exist
  --setup-mihomo           Deploy Mihomo after base init, applying shell and apt proxy settings
  --mihomo-config PATH     Local Mihomo/Clash config (auto-discovered if omitted)
  --mihomo-binary PATH     Optional local Mihomo binary to upload
  --mihomo-apply-git       Also configure remote git proxy through Mihomo
  --mihomo-apply-docker    Also configure Docker proxy through Mihomo and restart Docker
  --dry-run                Print actions without changing remote state
  -h, --help               Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:?}"; shift 2 ;;
    --ssh-port) SSH_PORT="${2:?}"; shift 2 ;;
    --sandbox) SANDBOX="${2:?}"; shift 2 ;;
    --workspace) WORKSPACE="${2:?}"; WORKSPACE_SET=1; shift 2 ;;
    --packages) PACKAGES="${2:?}"; shift 2 ;;
    --setup-git) SETUP_GIT=1; shift ;;
    --git-key-path) GIT_KEY_PATH="${2:?}"; shift 2 ;;
    --forward-agent) FORWARD_AGENT=1; shift ;;
    --upload-key) UPLOAD_KEY="${2:?}"; shift 2 ;;
    --git-name) GIT_NAME="${2:?}"; shift 2 ;;
    --git-email) GIT_EMAIL="${2:?}"; shift 2 ;;
    --setup-cache) SETUP_CACHE=1; shift ;;
    --copy-netrc) COPY_NETRC=1; shift ;;
    --install-codex) INSTALL_CODEX=1; shift ;;
    --install-kimi) INSTALL_KIMI=1; shift ;;
    --install-ai-clis) INSTALL_CODEX=1; INSTALL_KIMI=1; shift ;;
    --init-conda) INIT_CONDA=1; shift ;;
    --conda-path) CONDA_PATH="${2:?}"; shift 2 ;;
    --create-venv) CREATE_VENV="${2:?}"; shift 2 ;;
    --setup-mihomo) SETUP_MIHOMO=1; shift ;;
    --mihomo-config) MIHOMO_CONFIG="${2:?}"; shift 2 ;;
    --mihomo-binary) MIHOMO_BINARY="${2:?}"; shift 2 ;;
    --mihomo-apply-git) MIHOMO_APPLY_GIT=1; shift ;;
    --mihomo-apply-docker) MIHOMO_APPLY_DOCKER=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$HOST" ]]; then
  usage >&2
  exit 2
fi

case "$SANDBOX" in
  autodl)
    if [[ "$WORKSPACE_SET" -eq 0 ]]; then
      WORKSPACE="/root/autodl-tmp"
    fi
    ;;
  runpod)
    if [[ "$WORKSPACE_SET" -eq 0 ]]; then
      WORKSPACE="/workspace"
    fi
    ;;
  generic)
    if [[ "$WORKSPACE_SET" -eq 0 ]]; then
      echo "--workspace is required when --sandbox generic is used" >&2
      exit 2
    fi
    ;;
  *)
    echo "Unsupported sandbox: $SANDBOX. Use autodl, runpod, or generic." >&2
    exit 2
    ;;
esac

if [[ -z "$CONDA_PATH" ]]; then
  CONDA_PATH="$WORKSPACE/miniconda3/bin/conda"
fi

auto_discover_key() {
  local key
  for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ecdsa"; do
    if [[ -f "$key" ]]; then
      echo "$key"
      return 0
    fi
  done
  return 1
}

# Resolve Git key strategy
if [[ "$SETUP_GIT" -eq 1 ]]; then
  if [[ "$FORWARD_AGENT" -eq 1 ]]; then
    GIT_KEY_PATH="FORWARD_AGENT"
  elif [[ -n "$UPLOAD_KEY" ]]; then
    if [[ ! -f "$UPLOAD_KEY" ]]; then
      echo "Upload key not found locally: $UPLOAD_KEY" >&2
      exit 1
    fi
    GIT_KEY_PATH="$WORKSPACE/my_key"
  else
    # Auto-discover local key
    discovered_key="$(auto_discover_key || true)"
    if [[ -n "$discovered_key" ]]; then
      echo "Auto-discovered local SSH key: $discovered_key"
      UPLOAD_KEY="$discovered_key"
      GIT_KEY_PATH="$WORKSPACE/my_key"
    else
      echo "No local SSH key found in ~/.ssh/ (id_ed25519, id_rsa, id_ecdsa)." >&2
      echo "Use --upload-key PATH to specify one, or --forward-agent to use agent forwarding." >&2
      exit 1
    fi
  fi
else
  GIT_KEY_PATH="$WORKSPACE/my_key"
fi

auto_discover_mihomo_config() {
  local candidates=(
    "$HOME/.config/clash.meta/clashteng.yaml"
    "$HOME/.config/clash.meta/config.yaml"
    "$HOME/.config/clash/config.yaml"
    "$HOME/.config/mihomo/config.yaml"
  )
  for c in "${candidates[@]}"; do
    if [[ -f "$c" ]] && grep -q '^proxies:' "$c" 2>/dev/null; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

if [[ "$SETUP_MIHOMO" -eq 1 && -z "$MIHOMO_CONFIG" ]]; then
  discovered_config="$(auto_discover_mihomo_config || true)"
  if [[ -n "$discovered_config" ]]; then
    echo "Auto-discovered local Mihomo config: $discovered_config"
    MIHOMO_CONFIG="$discovered_config"
  else
    echo "No local Mihomo config found. Use --mihomo-config PATH to specify one." >&2
    exit 1
  fi
fi

ssh_cmd=(ssh -p "$SSH_PORT" -o BatchMode=yes -o ConnectTimeout=15)
if [[ "$FORWARD_AGENT" -eq 1 ]]; then
  ssh_cmd+=(-A)
fi
ssh_cmd+=("$HOST")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_remote() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run ssh %s] %s\n' "$HOST" "$*"
  else
    "${ssh_cmd[@]}" "$@"
  fi
}

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

remote_script="$tmpdir/ubuntu-server-init-remote.sh"
cat > "$remote_script" <<'REMOTE'
#!/usr/bin/env bash
set -euo pipefail

workspace="${1:?}"
packages="${2:?}"
setup_git="${3:?}"
git_key_path="${4:?}"
git_name="${5:?}"
git_email="${6:?}"
setup_cache="${7:?}"
copy_netrc="${8:?}"
init_conda="${9:?}"
conda_path="${10:?}"
create_venv="${11:-}"

stamp="$(date +%Y%m%d%H%M%S)"

sudo_cmd() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local backup="${path}.bak.${stamp}"
    mv "$path" "$backup"
    echo "backup: $backup"
  fi
}

append_once() {
  local line="$1"
  local file="$2"
  touch "$file"
  grep -Fqx "$line" "$file" || echo "$line" >> "$file"
}

if [[ ! -f /etc/os-release ]]; then
  echo "Cannot identify OS: /etc/os-release missing" >&2
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *"debian"* ]]; then
  echo "Warning: expected Ubuntu/Debian-like OS, got ID=${ID:-unknown}" >&2
fi

if ! command -v sudo >/dev/null 2>&1 && [[ "$(id -u)" -ne 0 ]]; then
  echo "sudo is required for non-root initialization" >&2
  exit 1
fi

sudo_cmd mkdir -p "$workspace"
sudo_cmd chown "$(id -u):$(id -g)" "$workspace" 2>/dev/null || true

sudo_cmd apt-get update
sudo_cmd env DEBIAN_FRONTEND=noninteractive apt-get install -y $packages
if command -v git-lfs >/dev/null 2>&1; then
  git lfs install
fi

if [[ "$setup_git" == "1" ]]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if [[ -n "$git_key_path" && "$git_key_path" != "FORWARD_AGENT" ]]; then
    if [[ ! -f "$git_key_path" ]]; then
      echo "Git key not found: $git_key_path" >&2
      exit 1
    fi
    if [[ -e "$HOME/.ssh/id_rsa" ]]; then
      cp -a "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_rsa.bak.$stamp"
      echo "backup: $HOME/.ssh/id_rsa.bak.$stamp"
    fi
    install -m 0600 "$git_key_path" "$HOME/.ssh/id_rsa"
    if [[ -e "$HOME/.ssh/config" ]]; then
      cp -a "$HOME/.ssh/config" "$HOME/.ssh/config.bak.$stamp"
      echo "backup: $HOME/.ssh/config.bak.$stamp"
    fi
    cat > "$HOME/.ssh/config" <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile $HOME/.ssh/id_rsa
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
EOF
    chmod 600 "$HOME/.ssh/config"
  fi
  git config --global user.name "$git_name"
  git config --global user.email "$git_email"
  ssh -T git@github.com || true
fi

if [[ "$setup_cache" == "1" ]]; then
  mkdir -p "$workspace/.cache"
  if [[ -L "$HOME/.cache" ]]; then
    rm "$HOME/.cache"
  elif [[ -e "$HOME/.cache" ]]; then
    backup_path "$HOME/.cache"
  fi
  ln -s "$workspace/.cache" "$HOME/.cache"
  echo "cache_link=$HOME/.cache -> $workspace/.cache"
fi

if [[ "$copy_netrc" == "1" ]]; then
  if [[ -f "$workspace/.netrc" ]]; then
    if [[ -e "$HOME/.netrc" ]]; then
      cp -a "$HOME/.netrc" "$HOME/.netrc.bak.$stamp"
      echo "backup: $HOME/.netrc.bak.$stamp"
    fi
    install -m 0600 "$workspace/.netrc" "$HOME/.netrc"
  else
    echo "netrc_missing=$workspace/.netrc"
  fi
fi

if [[ "$init_conda" == "1" ]]; then
  if [[ -x "$conda_path" ]]; then
    "$conda_path" init bash
  else
    echo "conda_missing=$conda_path" >&2
    exit 1
  fi
fi

if [[ -n "$create_venv" ]]; then
  mkdir -p "$(dirname "$create_venv")"
  if [[ ! -d "$create_venv" ]]; then
    python3 -m venv "$create_venv"
  fi
  "$create_venv/bin/python" --version
  "$create_venv/bin/pip" --version
fi

echo "versions:"
tmux -V || true
vim --version | sed -n '1p' || true
git --version || true
git lfs version || true
python3 --version || true


echo "ubuntu_server_init_complete=1"
REMOTE

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '[dry-run scp] %s -> %s:/tmp/ubuntu-server-init-remote.sh\n' "$remote_script" "$HOST"
  if [[ -n "$UPLOAD_KEY" ]]; then
    printf '[dry-run scp] %s -> %s:%s/my_key\n' "$UPLOAD_KEY" "$HOST" "$WORKSPACE"
  fi
else
  scp -P "$SSH_PORT" -o ConnectTimeout=15 "$remote_script" "$HOST:/tmp/ubuntu-server-init-remote.sh"
  if [[ -n "$UPLOAD_KEY" ]]; then
    run_remote "mkdir -p '$WORKSPACE'"
    scp -P "$SSH_PORT" -o ConnectTimeout=15 "$UPLOAD_KEY" "$HOST:$WORKSPACE/my_key"
  fi
fi

run_remote "bash /tmp/ubuntu-server-init-remote.sh '$WORKSPACE' '$PACKAGES' '$SETUP_GIT' '$GIT_KEY_PATH' '$GIT_NAME' '$GIT_EMAIL' '$SETUP_CACHE' '$COPY_NETRC' '$INIT_CONDA' '$CONDA_PATH' '$CREATE_VENV'; status=\$?; rm -f /tmp/ubuntu-server-init-remote.sh; exit \$status"

if [[ "$SETUP_MIHOMO" -eq 1 ]]; then
  deploy_mihomo_script="$SCRIPT_DIR/../../deploy-ubuntu-mihomo/scripts/deploy_ubuntu_mihomo.sh"
  deploy_mihomo_script="$(cd "$(dirname "$deploy_mihomo_script")" && pwd)/$(basename "$deploy_mihomo_script")"
  if [[ ! -x "$deploy_mihomo_script" ]]; then
    echo "Mihomo deploy script not found or not executable: $deploy_mihomo_script" >&2
    exit 1
  fi
  if [[ -z "$MIHOMO_CONFIG" ]]; then
    echo "--mihomo-config is required when --setup-mihomo is used in this repo" >&2
    exit 2
  fi
  mihomo_args=(--host "$HOST" --ssh-port "$SSH_PORT" --config "$MIHOMO_CONFIG" --apply-shell --apply-apt)
  if [[ -n "$MIHOMO_BINARY" ]]; then
    mihomo_args+=(--mihomo-binary "$MIHOMO_BINARY")
  fi
  if [[ "$MIHOMO_APPLY_GIT" -eq 1 ]]; then
    mihomo_args+=(--apply-git)
  fi
  if [[ "$MIHOMO_APPLY_DOCKER" -eq 1 ]]; then
    mihomo_args+=(--apply-docker)
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    mihomo_args+=(--dry-run)
  fi
  "$deploy_mihomo_script" "${mihomo_args[@]}"
fi

if [[ "$INSTALL_CODEX" -eq 1 ]]; then
  codex_install_script="$tmpdir/install-codex-remote.sh"
  cat > "$codex_install_script" <<'CODEX_EOF'
#!/bin/bash
set -e

source /etc/profile.d/proxy.sh 2>/dev/null || true

node_ok=0
if command -v node >/dev/null 2>&1; then
  major=$(node --version | sed 's/v//' | cut -d. -f1)
  if [[ "$major" -ge 18 ]]; then
    node_ok=1
  fi
fi

if [[ "$node_ok" -eq 0 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

if command -v codex >/dev/null 2>&1; then
  echo "codex_already_installed=$(codex --version)"
else
  npm install -g @openai/codex
fi

mkdir -p "$HOME/.codex"
touch "$HOME/.codex/config.toml"
tmp_config="$(mktemp)"
grep -Ev '^(approval_policy|sandbox_mode)[[:space:]]*=' "$HOME/.codex/config.toml" > "$tmp_config"
{
  printf 'approval_policy = "never"\n'
  printf 'sandbox_mode = "danger-full-access"\n\n'
  cat "$tmp_config"
} > "$HOME/.codex/config.toml"
rm -f "$tmp_config"
echo "codex_version=$(codex --version)"
CODEX_EOF

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run scp] %s -> %s:/tmp/install-codex-remote.sh\n' "$codex_install_script" "$HOST"
    printf '[dry-run ssh %s] bash -l /tmp/install-codex-remote.sh; status=$?; rm -f /tmp/install-codex-remote.sh; exit $status\n' "$HOST"
  else
    scp -P "$SSH_PORT" -o ConnectTimeout=15 "$codex_install_script" "$HOST:/tmp/install-codex-remote.sh"
    run_remote "bash -l /tmp/install-codex-remote.sh; status=\$?; rm -f /tmp/install-codex-remote.sh; exit \$status"
  fi
fi

if [[ "$INSTALL_KIMI" -eq 1 ]]; then
  kimi_install_script="$tmpdir/install-kimi-remote.sh"
  cat > "$kimi_install_script" <<'KIMI_EOF'
#!/bin/bash
set -e

source /etc/profile.d/proxy.sh 2>/dev/null || true

if command -v kimi >/dev/null 2>&1; then
  echo "kimi_already_installed=$(kimi --version)"
else
  curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash
fi

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if [[ -x "$HOME/.kimi-code/bin/kimi" ]]; then
  install -d /usr/local/bin
  ln -sf "$HOME/.kimi-code/bin/kimi" /usr/local/bin/kimi
  cat >/etc/profile.d/kimi.sh <<EOF
export PATH="$HOME/.kimi-code/bin:\$PATH"
EOF
fi
grep -Fqx 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
mkdir -p "$HOME/.kimi"
touch "$HOME/.kimi/config.toml"
tmp_config="$(mktemp)"
grep -Ev '^default_yolo[[:space:]]*=' "$HOME/.kimi/config.toml" > "$tmp_config"
{
  printf 'default_yolo = true\n\n'
  cat "$tmp_config"
} > "$HOME/.kimi/config.toml"
rm -f "$tmp_config"
echo "kimi_version=$(kimi --version)"
KIMI_EOF

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run scp] %s -> %s:/tmp/install-kimi-remote.sh\n' "$kimi_install_script" "$HOST"
    printf '[dry-run ssh %s] bash -l /tmp/install-kimi-remote.sh; status=$?; rm -f /tmp/install-kimi-remote.sh; exit $status\n' "$HOST"
  else
    scp -P "$SSH_PORT" -o ConnectTimeout=15 "$kimi_install_script" "$HOST:/tmp/install-kimi-remote.sh"
    run_remote "bash -l /tmp/install-kimi-remote.sh; status=\$?; rm -f /tmp/install-kimi-remote.sh; exit \$status"
  fi
fi

cat <<EOF

Ubuntu server init finished.
Remote: $HOST
Sandbox: $SANDBOX
Workspace: $WORKSPACE
Mihomo: $SETUP_MIHOMO
Codex: $INSTALL_CODEX
Kimi: $INSTALL_KIMI
EOF
