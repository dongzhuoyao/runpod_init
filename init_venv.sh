#!/usr/bin/env bash
set -e

VENV_PATH="/workspace/venv"
ACTIVATE_SCRIPT="${VENV_PATH}/bin/activate"

echo "Activating Python virtual environment..."

if [ ! -d "${VENV_PATH}" ]; then
    echo "Error: Virtual environment not found at ${VENV_PATH}"
    echo "Please create it first with: python3 -m venv ${VENV_PATH}"
    exit 1
fi

if [ ! -f "${ACTIVATE_SCRIPT}" ]; then
    echo "Error: Activation script not found at ${ACTIVATE_SCRIPT}"
    exit 1
fi

source "${ACTIVATE_SCRIPT}"

# Verify activation and show Python info
if [ -n "${VIRTUAL_ENV}" ]; then
    echo "Virtual environment activated: ${VIRTUAL_ENV}"
    echo "Python version: $(python --version)"
    echo "Pip version: $(pip --version)"
else
    echo "Warning: Virtual environment may not have activated correctly"
    exit 1
fi