# RunPod Initialization Scripts

This repository contains initialization scripts for setting up a RunPod environment.

## Scripts

### `init.sh` (Main Script)
The main initialization script that orchestrates the setup process:
- Installs essential packages: `tmux`, `vim`, `git`
- Sets up Git SSH configuration
- Copies `.netrc` file to `/root/` (if it exists)

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

## Prerequisites

Before running the scripts, ensure:
1. You have root/sudo access
2. `/workspace/my_key` exists (for Git SSH setup)
3. `/workspace/.netrc` exists (optional, for Git credentials)

## Features

- ✅ Error handling with `set -e`
- ✅ Relative path detection (scripts work from any location)
- ✅ File existence checks before operations
- ✅ Informative progress messages
- ✅ Modular design (scripts can be run individually)

## Notes

- The scripts are designed to run as root
- SSH keys and configs are set up in `/root/.ssh/`
- Git is configured globally with user email: `taohu620@gmail.com` and name: `Tao`
