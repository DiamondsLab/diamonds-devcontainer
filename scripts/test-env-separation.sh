#!/bin/bash
# Test script to verify .env file separation
# Ensures .devcontainer/.env and PROJECT_ROOT/.env are separate files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEVCONTAINER_ENV="${PROJECT_ROOT}/.devcontainer/.env"
PROJECT_ENV="${PROJECT_ROOT}/.env"

echo "Testing .env file separation..."
echo "================================"
echo "DevContainer .env: $DEVCONTAINER_ENV"
echo "Project .env:      $PROJECT_ENV"
echo
echo "NOTE: This test checks the CURRENT container state."
echo "If separation fails, you need to restart the DevContainer:"
echo "  Ctrl+Shift+P → 'Dev Containers: Rebuild Container'"
echo

# Check if DevContainer .env exists
if [[ -f "$DEVCONTAINER_ENV" ]]; then
    echo "✓ .devcontainer/.env exists"
else
    echo "✗ .devcontainer/.env does not exist"
    exit 1
fi

# Check if they are the same file (they should NOT be)
if [[ "$DEVCONTAINER_ENV" -ef "$PROJECT_ENV" ]]; then
    echo "✗ ERROR: .env files are the SAME file (separation failed)"
    echo "  This means the Docker volume mount is still active"
    exit 1
else
    echo "✓ .env files are SEPARATE files (separation successful)"
fi

# Check if project .env exists (optional)
if [[ -f "$PROJECT_ENV" ]]; then
    echo "✓ PROJECT_ROOT/.env exists"
else
    echo "⚠ PROJECT_ROOT/.env does not exist (this is OK for new setups)"
fi

echo
echo "File details:"
ls -la "$DEVCONTAINER_ENV"
if [[ -f "$PROJECT_ENV" ]]; then
    ls -la "$PROJECT_ENV"
fi

echo
echo "Test completed successfully!"
echo "The .env files are properly separated."