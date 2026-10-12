#!/usr/bin/env bash
# Deploy child app to AWS dev (Lambda). Used by GitHub Actions and CodeBuild.
set -euo pipefail

APP_DIR="${APP_DIR:-.}"
DEPLOY_TOOL="${DEPLOY_TOOL:-sst}"          # sst | sam | custom
DEPLOY_COMMAND="${DEPLOY_COMMAND:-}"
SST_STAGE="${SST_STAGE:-dev}"
SST_PATH="${SST_PATH:-.}"                  # relative to APP_DIR
AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

cd "${APP_DIR}"
echo "==> dev:deploy in $(pwd) tool=${DEPLOY_TOOL} region=${AWS_REGION}"

export AWS_REGION
export AWS_DEFAULT_REGION="${AWS_REGION}"

case "${DEPLOY_TOOL}" in
  sst)
    SST_DIR="${SST_PATH}"
    if [[ ! -f "${SST_DIR}/sst.config.ts" ]] && [[ ! -f "${SST_DIR}/sst.config.js" ]]; then
      echo "SST config not found under ${APP_DIR}/${SST_DIR}." >&2
      echo "Add sst.config.ts (OpenNext) or set DEPLOY_TOOL=custom." >&2
      exit 1
    fi
    # Install from app root when monorepo lockfile lives there
    if [[ ! -d node_modules ]] && [[ -f package.json ]]; then
      npm ci
    fi
    (
      cd "${SST_DIR}"
      npx --yes sst deploy --stage "${SST_STAGE}"
    )
    ;;
  sam)
    if [[ ! -f template.yaml ]] && [[ ! -f template.yml ]]; then
      echo "SAM template.yaml not found in ${APP_DIR}." >&2
      exit 1
    fi
    sam build
    sam deploy --no-confirm-changeset --no-fail-on-empty-changeset \
      --stack-name "${SAM_STACK_NAME:-keel-dev}" \
      --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
      --resolve-s3 \
      --region "${AWS_REGION}"
    ;;
  custom)
    if [[ -z "${DEPLOY_COMMAND}" ]]; then
      echo "DEPLOY_TOOL=custom requires DEPLOY_COMMAND." >&2
      exit 1
    fi
    echo "==> DEPLOY_COMMAND=${DEPLOY_COMMAND}"
    eval "${DEPLOY_COMMAND}"
    ;;
  *)
    echo "Unknown DEPLOY_TOOL=${DEPLOY_TOOL} (use sst|sam|custom)." >&2
    exit 1
    ;;
esac

echo "==> dev:deploy finished"
