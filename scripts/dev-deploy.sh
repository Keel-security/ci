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
KEEL_ENV="${KEEL_ENV:-dev}"
echo "==> deploy in $(pwd) tool=${DEPLOY_TOOL} region=${AWS_REGION} keel_env=${KEEL_ENV}"

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
    if [[ ! -d node_modules ]] && [[ -f package.json ]]; then
      npm install
    fi

    # Resolve platform config from keel-infra SSM when not provided as env secrets.
    if [[ -z "${DATABASE_URL:-}" ]] && command -v aws >/dev/null 2>&1; then
      DATABASE_URL="$(aws ssm get-parameter --name "/keel/${KEEL_ENV}/DATABASE_URL" --with-decryption --query Parameter.Value --output text 2>/dev/null || true)"
      export DATABASE_URL
    fi
    if [[ -z "${LAMBDA_SUBNET_IDS:-}" ]] && command -v aws >/dev/null 2>&1; then
      LAMBDA_SUBNET_IDS="$(aws ssm get-parameter --name "/keel/${KEEL_ENV}/LAMBDA_SUBNET_IDS" --query Parameter.Value --output text 2>/dev/null || true)"
    fi
    if [[ -z "${LAMBDA_SECURITY_GROUP_ID:-}" ]] && command -v aws >/dev/null 2>&1; then
      LAMBDA_SECURITY_GROUP_ID="$(aws ssm get-parameter --name "/keel/${KEEL_ENV}/LAMBDA_SECURITY_GROUP_ID" --query Parameter.Value --output text 2>/dev/null || true)"
    fi

    OVERRIDES=("DatabaseUrl=${DATABASE_URL:?DATABASE_URL required (secret or SSM /keel/${KEEL_ENV}/DATABASE_URL)}")
    if [[ -n "${LAMBDA_SUBNET_IDS:-}" && -n "${LAMBDA_SECURITY_GROUP_ID:-}" ]]; then
      OVERRIDES+=("LambdaSubnetIds=${LAMBDA_SUBNET_IDS}")
      OVERRIDES+=("LambdaSecurityGroupIds=${LAMBDA_SECURITY_GROUP_ID}")
    fi

    # Auto custom DNS: stack keel-<service>-* → <service>.<api-dns-suffix>
    # Infra publishes wildcard cert + zone once; this stack creates the subdomain.
    if [[ -n "${SAM_STACK_NAME:-}" ]] && command -v aws >/dev/null 2>&1; then
      SERVICE_KEY="${SERVICE_NAME:-$(echo "${SAM_STACK_NAME}" | sed -E 's/^keel-([a-z0-9]+)-.*/\1/')}"
      if [[ -n "${SERVICE_KEY}" && "${SERVICE_KEY}" != "${SAM_STACK_NAME}" ]]; then
        API_DNS_SUFFIX="$(aws ssm get-parameter --name "/keel/${KEEL_ENV}/api-dns-suffix" --query Parameter.Value --output text 2>/dev/null || true)"
        API_HOSTED_ZONE_ID="$(aws ssm get-parameter --name "/keel/${KEEL_ENV}/api-hosted-zone-id" --query Parameter.Value --output text 2>/dev/null || true)"
        API_CERTIFICATE_ARN="$(aws ssm get-parameter --name "/keel/${KEEL_ENV}/api-certificate-arn" --query Parameter.Value --output text 2>/dev/null || true)"
        if [[ -n "${API_DNS_SUFFIX}" && "${API_DNS_SUFFIX}" != "None" && \
              -n "${API_HOSTED_ZONE_ID}" && "${API_HOSTED_ZONE_ID}" != "None" && \
              -n "${API_CERTIFICATE_ARN}" && "${API_CERTIFICATE_ARN}" != "None" ]]; then
          OVERRIDES+=("ServiceName=${SERVICE_KEY}")
          OVERRIDES+=("ApiDnsSuffix=${API_DNS_SUFFIX}")
          OVERRIDES+=("ApiHostedZoneId=${API_HOSTED_ZONE_ID}")
          OVERRIDES+=("ApiCertificateArn=${API_CERTIFICATE_ARN}")
          echo "==> Custom DNS https://${SERVICE_KEY}.${API_DNS_SUFFIX}/"
        fi
      fi
    fi

    sam build
    sam deploy --no-confirm-changeset --no-fail-on-empty-changeset \
      --stack-name "${SAM_STACK_NAME:-keel-dev}" \
      --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
      --resolve-s3 \
      --region "${AWS_REGION}" \
      --parameter-overrides "${OVERRIDES[@]}"
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
