#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/fastapi-app"

cd "${APP_DIR}"
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
"${APP_DIR}/.venv/bin/pip" install --upgrade pip
if [ -f requirements.txt ]; then
  "${APP_DIR}/.venv/bin/pip" install -r requirements.txt
fi
