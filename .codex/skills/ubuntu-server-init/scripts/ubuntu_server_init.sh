#!/usr/bin/env bash
set -euo pipefail

HOST=""
SSH_PORT="22"
SANDBOX="autodl"
WORKSPACE=""
WORKSPACE_SET=0
PACKAGES="tmux vim git curl ca-certificates openssh-client python3 python3-venv"
SETUP_GIT=0
SETUP_CACHE=0
COPY_NETRC=0
INSTALL_CLAUDE=0
INSTALL_OPENCODE=0
INIT_CONDA=0
CREATE_VENV=""
SETUP_MIHOMO=0
MIHOMO_CONFIG=""
MIHOMO_BINARY=""
MIHOMO_APPLY_GIT=0
MIHOMO_APPLY_DOCKER=0
GIT_KEY_PATH=""
GIT_NAME="Tao"
GIT_EMAIL="taohu620@gmail.com"
CONDA_PATH=""
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
  --git-name NAME          Git user.name, default Tao
  --git-email EMAIL        Git user.email, default taohu620@gmail.com
  --setup-cache            Link ~/.cache to WORKSPACE/.cache
  --copy-netrc             Copy WORKSPACE/.netrc to ~/.netrc when present
  --install-claude         Install Claude CLI using the official installer
  --install-opencode       Install OpenCode using the official installer
  --init-conda             Run conda init bash if conda exists
  --conda-path PATH        Conda binary path, default WORKSPACE/miniconda3/bin/conda
  --create-venv PATH       Create a Python venv if it does not exist
  --setup-mihomo           Deploy Mihomo after base init, applying shell and apt proxy settings
  --mihomo-config PATH     Local Mihomo/Clash config, default clash/clashteng.yaml
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
    --git-name) GIT_NAME="${2:?}"; shift 2 ;;
    --git-email) GIT_EMAIL="${2:?}"; shift 2 ;;
    --setup-cache) SETUP_CACHE=1; shift ;;
    --copy-netrc) COPY_NETRC=1; shift ;;
    --install-claude) INSTALL_CLAUDE=1; shift ;;
    --install-opencode) INSTALL_OPENCODE=1; shift ;;
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

if [[ -z "$GIT_KEY_PATH" ]]; then
  GIT_KEY_PATH="$WORKSPACE/my_key"
fi

if [[ -z "$CONDA_PATH" ]]; then
  CONDA_PATH="$WORKSPACE/miniconda3/bin/conda"
fi

ssh_cmd=(ssh -p "$SSH_PORT" -o BatchMode=yes -o ConnectTimeout=15 "$HOST")
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
install_claude="${9:?}"
install_opencode="${10:?}"
init_conda="${11:?}"
conda_path="${12:?}"
create_venv="${13:?}"

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

if [[ "$setup_git" == "1" ]]; then
  if [[ ! -f "$git_key_path" ]]; then
    echo "Git key not found: $git_key_path" >&2
    exit 1
  fi
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
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

if [[ "$install_claude" == "1" ]]; then
  curl -fsSL https://claude.ai/install.sh | bash
  append_once 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"
fi

if [[ "$install_opencode" == "1" ]]; then
  curl -fsSL https://opencode.ai/install | bash
  append_once 'export PATH="$HOME/.opencode/bin:$PATH"' "$HOME/.bashrc"
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
python3 --version || true
command -v claude >/dev/null 2>&1 && claude --version || true
command -v opencode >/dev/null 2>&1 && opencode --version || true

echo "ubuntu_server_init_complete=1"
REMOTE

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '[dry-run scp] %s -> %s:/tmp/ubuntu-server-init-remote.sh\n' "$remote_script" "$HOST"
else
  scp -P "$SSH_PORT" "$remote_script" "$HOST:/tmp/ubuntu-server-init-remote.sh"
fi

run_remote "bash /tmp/ubuntu-server-init-remote.sh '$WORKSPACE' '$PACKAGES' '$SETUP_GIT' '$GIT_KEY_PATH' '$GIT_NAME' '$GIT_EMAIL' '$SETUP_CACHE' '$COPY_NETRC' '$INSTALL_CLAUDE' '$INSTALL_OPENCODE' '$INIT_CONDA' '$CONDA_PATH' '$CREATE_VENV'; rm -f /tmp/ubuntu-server-init-remote.sh"

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

cat <<EOF

Ubuntu server init finished.
Remote: $HOST
Sandbox: $SANDBOX
Workspace: $WORKSPACE
Mihomo: $SETUP_MIHOMO
EOF
