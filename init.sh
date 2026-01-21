#!/usr/bin/env bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting initialization..."

# 1. Install essential packages
echo "Installing packages..."
apt update && apt install -y tmux vim git

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

# 5. Install Claude
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

curl -fsSL https://opencode.ai/install | bash


# 6. Optionally setup conda (uncomment if needed)
# echo "Setting up Conda..."
# bash "${SCRIPT_DIR}/init_conda.sh"

echo "Initialization complete!"