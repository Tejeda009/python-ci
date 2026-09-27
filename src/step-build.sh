#!/usr/bin/env psh
set -euo pipefail

PROJECT="${INPUT_PROJECT_PATH:-.}"
LOG="${INPUT_LOG_FILE:-pipery.jsonl}"

PM="${INPUT_PACKAGE_MANAGER:-auto}"
PM=$(echo "$PM" | tr '[:upper:]' '[:lower:]')

cd "$PROJECT"
BUILD_TOOL=""


if [ -z "$PM" ] || [ "$PM" = "auto" ]; then
  if [ -f pyproject.toml ]; then
    if grep -qE '^build-backend[[:space:]]*=[[:space:]]*["'\'']poetry\.core' pyproject.toml || grep -q '\[tool\.poetry\]' pyproject.toml; then
      PM="poetry"
    elif grep -qE '^build-backend[[:space:]]*=[[:space:]]*["'\'']hatchling\.build' pyproject.toml || grep -q '\[tool\.hatch' pyproject.toml; then
      PM="hatch"
    elif grep -qE '^build-backend[[:space:]]*=[[:space:]]*["'\'']flit_core\.build' pyproject.toml || grep -q '\[tool\.flit' pyproject.toml; then
      PM="flit"
    elif grep -qE '^build-backend[[:space:]]*=[[:space:]]*["'\'']uv_build' pyproject.toml || grep -q '\[tool\.uv\.build-backend\]' pyproject.toml; then
      PM="uv"
    else
      PM="python-build"
    fi
  elif [ -f setup.cfg ] || [ -f setup.py ]; then
    PM="python-build"
  else
    echo "No build system detected, skipping build."
    printf '{"event":"build","status":"skipped","reason":"no_build_system"}\n' >> "$LOG"
    exit 0
  fi
  echo "Autodetected package manager: $PM"
else
  echo "Using explicitly selected package manager: $PM"
fi

case "$PM" in
  poetry)
    pip install poetry -q 2>/dev/null || pip3 install poetry --break-system-packages -q 2>/dev/null || true
    poetry build
    BUILD_TOOL="poetry"
    ;;
  uv)
    pip install uv -q 2>/dev/null || pip3 install uv --break-system-packages -q 2>/dev/null || true
    uv build
    BUILD_TOOL="uv"
    ;;
  hatch)
    pip install hatch -q 2>/dev/null || pip3 install hatch --break-system-packages -q 2>/dev/null || true
    hatch build
    BUILD_TOOL="hatch"
    ;;
  flit)
    pip install flit -q 2>/dev/null || pip3 install flit --break-system-packages -q 2>/dev/null || true
    flit build
    BUILD_TOOL="flit"
    ;;
  python-build|build|pip|setuptools)
    pip install build -q 2>/dev/null || pip3 install build --break-system-packages -q 2>/dev/null || true
    python3 -m build
    BUILD_TOOL="python-build"
    ;;
  *)
    echo "Warning: Unrecognized package manager '$PM'. Falling back to 'python -m build'."
    pip install build -q 2>/dev/null || pip3 install build --break-system-packages -q 2>/dev/null || true
    python3 -m build
    BUILD_TOOL="python-build"
    ;;
esac

if [ -n "$BUILD_TOOL" ]; then
  printf '{"event":"build","status":"success","tool":"%s"}\n' "$BUILD_TOOL" >> "$LOG"
fi