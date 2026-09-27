#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="${GITHUB_ACTION_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SRC_DIR="${SCRIPT_DIR}/src"
WORKSPACE_DIR="$(pwd)"

export INPUT_PROJECT_PATH="${INPUT_PROJECT_PATH:-${PIPERY_TEST_PROJECT_PATH:-.}}"
export INPUT_LOG_FILE="${INPUT_LOG_FILE:-${PIPERY_LOG_PATH:-pipery.jsonl}}"

if [ ! -d "${INPUT_PROJECT_PATH}" ]; then
  echo "ERROR: project path does not exist: ${INPUT_PROJECT_PATH}" >&2
  exit 1
fi
INPUT_PROJECT_PATH="$(cd "${INPUT_PROJECT_PATH}" && pwd)"
export INPUT_PROJECT_PATH

echo "==> pipery-python-ci starting"
echo "    project_path=${INPUT_PROJECT_PATH}"
echo "    log_file=${INPUT_LOG_FILE}"

# Setup psh wrapper
mkdir -p /tmp/pipery-test-bin
printf '#!/bin/bash\nexec bash "$@"\n' > /tmp/pipery-test-bin/psh
chmod +x /tmp/pipery-test-bin/psh
export PATH="/tmp/pipery-test-bin:$PATH"

if ! command -v pipery-steps >/dev/null 2>&1; then
  echo "==> Installing pipery-tooling (and yaml dependencies)..."
  pip install git+https://github.com/pipery-dev/pipery-tooling.git -q 2>/dev/null || \
    pip3 install git+https://github.com/pipery-dev/pipery-tooling.git -q 2>/dev/null || true
fi

pip install pyyaml -q 2>/dev/null || pip3 install pyyaml -q 2>/dev/null || true

export INPUT_CONFIG_FILE="${INPUT_CONFIG_FILE:-.pipery/config.yaml}"
if [[ "${INPUT_CONFIG_FILE}" = /* ]]; then
  CONFIG_PATH="${INPUT_CONFIG_FILE}"
else
  CONFIG_PATH="${INPUT_PROJECT_PATH}/${INPUT_CONFIG_FILE}"
fi


if [ "${INPUT_PACKAGE_MANAGER:-auto}" = "auto" ]; then unset INPUT_PACKAGE_MANAGER; fi
if [ "${INPUT_PYTHON_VERSION:-3.11}" = "3.11" ]; then unset INPUT_PYTHON_VERSION; fi
if [ "${INPUT_SKIP_SAST:-false}" = "false" ]; then unset INPUT_SKIP_SAST; fi
if [ "${INPUT_SKIP_SCA:-false}" = "false" ]; then unset INPUT_SKIP_SCA; fi
if [ "${INPUT_SKIP_LINT:-false}" = "false" ]; then unset INPUT_SKIP_LINT; fi
if [ "${INPUT_SKIP_BUILD:-false}" = "false" ]; then unset INPUT_SKIP_BUILD; fi
if [ -z "${INPUT_TESTS_PATH:-}" ]; then unset INPUT_TESTS_PATH; fi
if [ "${INPUT_SKIP_TEST:-false}" = "false" ]; then unset INPUT_SKIP_TEST; fi
if [ "${INPUT_SKIP_VERSIONING:-false}" = "false" ]; then unset INPUT_SKIP_VERSIONING; fi
if [ "${INPUT_SKIP_PACKAGING:-false}" = "false" ]; then unset INPUT_SKIP_PACKAGING; fi
if [ "${INPUT_SKIP_RELEASE:-false}" = "false" ]; then unset INPUT_SKIP_RELEASE; fi
if [ "${INPUT_SKIP_REINTEGRATION:-false}" = "false" ]; then unset INPUT_SKIP_REINTEGRATION; fi
if [ "${INPUT_VERSION_BUMP:-patch}" = "patch" ]; then unset INPUT_VERSION_BUMP; fi
if [ "${INPUT_REGISTRY:-pypi}" = "pypi" ]; then unset INPUT_REGISTRY; fi
if [ "${INPUT_TARGET_BRANCH:-main}" = "main" ]; then unset INPUT_TARGET_BRANCH; fi
if [ "${INPUT_LOG_FILE:-pipery.jsonl}" = "pipery.jsonl" ]; then unset INPUT_LOG_FILE; fi


if [ -x "${SRC_DIR}/read-config.sh" ]; then
  while IFS=$'\t' read -r env_key encoded_value; do
    [ -n "${env_key}" ] || continue
    config_value="$(printf '%s' "${encoded_value}" | base64 --decode)"
    export "${env_key}=${config_value}"
  done < <("${SRC_DIR}/read-config.sh" "${CONFIG_PATH}")
fi


export INPUT_PACKAGE_MANAGER="${INPUT_PACKAGE_MANAGER:-auto}"
export INPUT_PYTHON_VERSION="${INPUT_PYTHON_VERSION:-3.11}"
export INPUT_SKIP_SAST="${INPUT_SKIP_SAST:-false}"
export INPUT_SKIP_SCA="${INPUT_SKIP_SCA:-false}"
export INPUT_SKIP_LINT="${INPUT_SKIP_LINT:-false}"
export INPUT_SKIP_BUILD="${INPUT_SKIP_BUILD:-false}"
export INPUT_SKIP_TEST="${INPUT_SKIP_TEST:-false}"
export INPUT_SKIP_VERSIONING="${INPUT_SKIP_VERSIONING:-false}"
export INPUT_SKIP_PACKAGING="${INPUT_SKIP_PACKAGING:-false}"
export INPUT_SKIP_RELEASE="${INPUT_SKIP_RELEASE:-false}"
export INPUT_SKIP_REINTEGRATION="${INPUT_SKIP_REINTEGRATION:-false}"
export INPUT_VERSION_BUMP="${INPUT_VERSION_BUMP:-patch}"
export INPUT_REGISTRY="${INPUT_REGISTRY:-pypi}"
export INPUT_PYPI_TOKEN="${INPUT_PYPI_TOKEN:-}"
export INPUT_GITHUB_TOKEN="${INPUT_GITHUB_TOKEN:-}"

LOG_FILE="${INPUT_LOG_FILE:-pipery.jsonl}"
if [[ "${LOG_FILE}" = /* ]]; then
  export INPUT_LOG_FILE="${LOG_FILE}"
else
  export INPUT_LOG_FILE="${WORKSPACE_DIR}/${LOG_FILE}"
fi
mkdir -p "$(dirname "${INPUT_LOG_FILE}")"

# Esecuzione Steps
if [ "${INPUT_SKIP_SAST}" != "true" ]; then
  echo "==> SAST scan"
  "${SRC_DIR}/step-sast.sh" || { echo "SAST step failed" >&2; exit 1; }
fi

if [ "${INPUT_SKIP_SCA}" != "true" ]; then
  echo "==> SCA scan"
  "${SRC_DIR}/step-sca.sh" || { echo "SCA step failed" >&2; exit 1; }
fi

if [ "${INPUT_SKIP_LINT}" != "true" ]; then
  echo "==> Lint"
  "${SRC_DIR}/step-lint.sh" || { echo "Lint step failed" >&2; exit 1; }
fi

if [ "${INPUT_SKIP_BUILD}" != "true" ]; then
  echo "==> Build"
  "${SRC_DIR}/step-build.sh" || { echo "Build step failed" >&2; exit 1; }
fi

if [ "${INPUT_SKIP_TEST}" != "true" ]; then
  echo "==> Test"
  "${SRC_DIR}/step-test.sh" || { echo "Test step failed" >&2; exit 1; }
fi

if [ "${INPUT_SKIP_VERSIONING}" != "true" ]; then
  echo "==> Version"
  "${SRC_DIR}/step-version.sh" || { echo "Version step failed" >&2; exit 1; }
fi

if [ "${INPUT_SKIP_PACKAGING}" != "true" ]; then
  echo "==> Package"
  "${SRC_DIR}/step-package.sh" || { echo "Package step failed" >&2; exit 1; }
fi

if [ "${INPUT_SKIP_RELEASE}" != "true" ]; then
  echo "==> Release"
  "${SRC_DIR}/step-release.sh" || { echo "Release step failed" >&2; exit 1; }
fi

if [ "${INPUT_SKIP_REINTEGRATION}" != "true" ]; then
  echo "==> Reintegrate"
  "${SRC_DIR}/step-reintegrate.sh" || { echo "Reintegrate step failed" >&2; exit 1; }
fi

printf '{"event":"build","status":"success","project":"python","mode":"ci"}\n' >> "${INPUT_LOG_FILE}"
echo "==> pipery-python-ci complete"