#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-${INPUT_CONFIG_FILE:-.pipery/config.yaml}}"

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "Config file not found: ${CONFIG_FILE} — skipping" >&2
  exit 0
fi

echo "==> Reading config from ${CONFIG_FILE}" >&2
python3 - "${CONFIG_FILE}" <<'PY'
import base64
import os
import sys

import yaml

with open(sys.argv[1], encoding="utf-8") as config_file:
  config = yaml.safe_load(config_file) or {}

for key, value in config.items():
  env_key = "INPUT_" + str(key).upper().replace("-", "_")
  if env_key in os.environ or not isinstance(value, (str, int, float, bool)):
    continue
  if isinstance(value, bool):
    value = str(value).lower()
  encoded = base64.b64encode(str(value).encode()).decode()
  print(f"{env_key}\t{encoded}")
PY
