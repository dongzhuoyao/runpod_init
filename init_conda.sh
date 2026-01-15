#!/usr/bin/env bash
set -e

echo "Initializing Conda..."

if [ -f /workspace/miniconda3/bin/conda ]; then
    /workspace/miniconda3/bin/conda init bash
    source ~/.bashrc
    echo "Conda initialized successfully!"
else
    echo "Error: Conda not found at /workspace/miniconda3/bin/conda"
    exit 1
fi
