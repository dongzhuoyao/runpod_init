#!/usr/bin/env bash
set -e

# .cache in ~/.cache consumes too much space, delete it and create a symlink to /workspace/.cache
echo "Setting up cache symlink..."

if [ -e ~/.cache ]; then
    if [ -L ~/.cache ]; then
        echo "Removing existing symlink ~/.cache..."
        rm ~/.cache
    else
        echo "Removing existing ~/.cache directory..."
        rm -rf ~/.cache
    fi
fi

# Create /workspace/.cache directory if it doesn't exist
mkdir -p /workspace/.cache

# Create symlink
ln -s /workspace/.cache ~/.cache
echo "Created symlink: ~/.cache -> /workspace/.cache"
