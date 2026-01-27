# RunPod Initialization Scripts

This repository contains initialization scripts for setting up a RunPod environment.

## Scripts

### `init.sh` (Main Script)
The main initialization script that orchestrates the setup process:
1. Installs essential packages: `tmux`, `vim`, `git`
2. Sets up Git SSH configuration
3. Sets up cache symlink to save disk space
4. Copies `.netrc` file to `/root/` (if it exists)
5. Installs Claude CLI and OpenCode.ai
6. Optionally sets up Conda (commented out by default)

**Usage:**
```bash
bash init.sh
# or
./init.sh
```

### `init_git.sh`
Configures Git and SSH for GitHub access:
- Creates `.ssh` directory with proper permissions
- Copies SSH private key from `/workspace/my_key`
- Sets up SSH config for GitHub
- Configures Git user name and email
- Tests GitHub SSH connection

**Requirements:**
- `/workspace/my_key` must exist (SSH private key)

### `init_cache.sh`
Optimizes disk space by redirecting cache to persistent storage:
- Removes existing `~/.cache` directory or symlink
- Creates `/workspace/.cache` directory
- Creates symlink from `~/.cache` to `/workspace/.cache`

**Purpose:** Prevents cache files from consuming space in the root filesystem by redirecting them to `/workspace/.cache`.

**Usage:**
```bash
bash init_cache.sh
```

### `init_conda.sh`
Initializes Conda environment:
- Runs `conda init bash`
- Sources `.bashrc` to activate conda

**Requirements:**
- Conda must be installed at `/workspace/miniconda3/bin/conda`

**Usage:**
```bash
bash init_conda.sh
```

### `init_venv.sh`
Activates Python virtual environment:
- Checks if virtual environment exists
- Activates the venv and verifies activation
- Displays Python and pip versions

**Requirements:**
- Virtual environment must exist at `/workspace/venv`

**Usage:**
```bash
# IMPORTANT: Must be sourced (not executed) to activate in current shell
source init_venv.sh
# or
. init_venv.sh
```

**Note:** This script must be sourced (using `source` or `.`) rather than executed directly, otherwise the virtual environment will only be activated in a subshell and won't affect your current shell session.

## Prerequisites

Before running the scripts, ensure:
1. You have root/sudo access
2. `/workspace/my_key` exists (SSH private key for Git setup)
3. `/workspace/.netrc` exists (optional, for Git credentials)
4. `/workspace/venv` exists (optional, for venv activation with `init_venv.sh`)
5. `/workspace/miniconda3/bin/conda` exists (optional, for Conda setup with `init_conda.sh`)

## Features

- ✅ Error handling with `set -e`
- ✅ Relative path detection (scripts work from any location)
- ✅ File existence checks before operations
- ✅ Informative progress messages
- ✅ Modular design (scripts can be run individually)
- ✅ Cache optimization to save disk space
- ✅ Automatic Claude CLI and OpenCode.ai installation

## Notes

- The scripts are designed to run as root
- SSH keys and configs are set up in `/root/.ssh/`
- Git is configured globally with user email: `taohu620@gmail.com` and name: `Tao`
- `init_venv.sh` must be sourced (not executed) to work properly in your current shell
- Cache redirection helps save space in the container's root filesystem
- Claude CLI is installed to `~/.local/bin/` and added to PATH
- Conda initialization is disabled by default in `init.sh` (uncomment line 37-38 to enable)