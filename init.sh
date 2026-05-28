#!/usr/bin/env bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting initialization..."

# 1. Install essential packages
echo "Installing packages..."
apt update && apt install -y tmux vim git git-lfs curl ca-certificates python3 python3-venv
git lfs install

# 2. Setup Git SSH configuration
echo "Setting up Git SSH..."
bash "${SCRIPT_DIR}/init_git.sh"

# 3. Setup cache symlink
echo "Setting up cache symlink..."
bash "${SCRIPT_DIR}/init_cache.sh"

# 4. Copy .netrc if it exists
if [ -f /workspace/.netrc ]; then
    echo "Copying .netrc..."
    cp /workspace/.netrc /root/
else
    echo "Warning: /workspace/.netrc not found, skipping..."
fi

# 5. Install AI CLIs
if ! command -v node >/dev/null 2>&1 || [ "$(node --version | sed 's/v//' | cut -d. -f1)" -lt 18 ]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt install -y nodejs
fi

if ! command -v codex >/dev/null 2>&1; then
    npm install -g @openai/codex
fi

mkdir -p "$HOME/.codex"
if [ ! -f "$HOME/.codex/config.toml" ]; then
    touch "$HOME/.codex/config.toml"
fi
tmp_codex_config="$(mktemp)"
grep -Ev '^(approval_policy|sandbox_mode)[[:space:]]*=' "$HOME/.codex/config.toml" > "$tmp_codex_config"
{
    printf 'approval_policy = "never"\n'
    printf 'sandbox_mode = "danger-full-access"\n\n'
    cat "$tmp_codex_config"
} > "$HOME/.codex/config.toml"
rm -f "$tmp_codex_config"

if ! command -v kimi >/dev/null 2>&1; then
    curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash
fi

export PATH="$HOME/.kimi-code/bin:$HOME/.local/bin:$PATH"
if [ -x "$HOME/.kimi-code/bin/kimi" ]; then
    ln -sf "$HOME/.kimi-code/bin/kimi" /usr/local/bin/kimi
fi
grep -Fqx 'export PATH="$HOME/.kimi-code/bin:$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null || \
    echo 'export PATH="$HOME/.kimi-code/bin:$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

mkdir -p "$HOME/.kimi"
if [ ! -f "$HOME/.kimi/config.toml" ]; then
    touch "$HOME/.kimi/config.toml"
fi
tmp_kimi_config="$(mktemp)"
grep -Ev '^default_yolo[[:space:]]*=' "$HOME/.kimi/config.toml" > "$tmp_kimi_config"
{
    printf 'default_yolo = true\n\n'
    cat "$tmp_kimi_config"
} > "$HOME/.kimi/config.toml"
rm -f "$tmp_kimi_config"


# 6. Optionally setup conda (uncomment if needed)
# echo "Setting up Conda..."
# bash "${SCRIPT_DIR}/init_conda.sh"

echo "Initialization complete!"
