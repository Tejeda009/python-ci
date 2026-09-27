#!/usr/bin/env bash
set -euo pipefail

PM="${PACKAGE_MANAGER:-${INPUT_PACKAGE_MANAGER:-auto}}"
PM=$(echo "$PM" | tr '[:upper:]' '[:lower:]')

if [ -z "$PM" ] || [ "$PM" = "auto" ]; then
    if [ -f "pyproject.toml" ]; then
        if grep -q -i "poetry" pyproject.toml; then
            PM="poetry"
        elif grep -q -i "hatch" pyproject.toml; then
            PM="hatch"
        elif grep -q -i "flit" pyproject.toml; then
            PM="flit"
        elif grep -q -i "uv" pyproject.toml; then
            PM="uv"
        else
            PM="pip"
        fi
    elif [ -f "setup.py" ]; then
        PM="setuptools"
    else
        PM="pip"
    fi
    echo "Autodetected package manager: $PM"
else
    echo "Using explicitly selected package manager: $PM"
fi

echo "::group::Building package with $PM"

case "$PM" in
    uv)
        uv build
        ;;
    poetry)
        poetry build
        ;;
    hatch)
        hatch build
        ;;
    flit)
        flit build
        ;;
    pip|setuptools|build)
        python -m build
        ;;
    *)
        echo "Warning: Unrecognized package manager '$PM'. Falling back to 'python -m build'."
        python -m build
        ;;
esac

echo "::endgroup::"
