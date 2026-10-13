#!/usr/bin/env bash
# Shared build entrypoint for Keel child repos.
set -euo pipefail

APP_DIR="${APP_DIR:-.}"
BUILD_COMMAND="${BUILD_COMMAND:-}"
NODE_VERSION="${NODE_VERSION:-22}"

cd "${APP_DIR}"
echo "==> build in $(pwd)"

if [[ -n "${BUILD_COMMAND}" ]]; then
  echo "==> BUILD_COMMAND=${BUILD_COMMAND}"
  eval "${BUILD_COMMAND}"
  exit 0
fi

if [[ -f package.json ]]; then
  echo "==> Node detected (package.json)"
  if command -v npm >/dev/null 2>&1; then
    if [[ -f package-lock.json ]]; then
      npm ci
    else
      npm install
    fi
    if npm run | grep -qE '^  build'; then
      npm run build
    else
      echo "==> no npm build script; install only"
    fi
  else
    echo "npm not found" >&2
    exit 1
  fi
  exit 0
fi

if [[ -f go.mod ]]; then
  echo "==> Go detected (go.mod)"
  go version
  go test ./...
  exit 0
fi

if [[ -f requirements.txt ]] || [[ -f pyproject.toml ]]; then
  echo "==> Python detected"
  python -m pip install -U pip
  if [[ -f requirements.txt ]]; then
    pip install -r requirements.txt
  fi
  if [[ -f pyproject.toml ]] && command -v pytest >/dev/null 2>&1; then
    pytest -q || true
  fi
  exit 0
fi

echo "No recognized project type in ${APP_DIR}; set BUILD_COMMAND." >&2
exit 1
