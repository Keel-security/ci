# Keel CI (GitHub Actions)

Shared reusable workflows + **central config** in this repo (works without org secrets on free plans).

## What lives in the CI repo (set once)

| File | Purpose |
|------|---------|
| [`config/regions.json`](config/regions.json) | Enable/disable `us` / `eu` for all children |
| [`config/infra.json`](config/infra.json) | TF state bucket name, lock table, region metadata |

Example — disable EU everywhere:

```json
{ "us": true, "eu": false }
```

Push to `Keel-security/ci` `main`; next child runs pick it up via `reusable-regions.yml`.

## What still must be per child repo

GitHub does **not** inherit secrets from the reusable-workflow repo. On free private orgs you cannot use org secrets either.

| Secret | Where | Why |
|--------|-------|-----|
| `AWS_ROLE_ARN` | Each private repo | OIDC assume-role (caller identity) |

Optional overrides: `TF_STATE_BUCKET`, `TF_LOCK_TABLE`, `DATABASE_URL_US` / `DATABASE_URL_EU` (else SSM `/keel/dev-*/DATABASE_URL`).

## Stages (multi-region)

| Job | Source |
|-----|--------|
| **regions** | `reusable-regions.yml` ← `config/regions.json` |
| **build** | `reusable-build.yml` |
| **dev:deploy-us** / **dev:deploy-eu** | `reusable-deploy.yml` (skipped if region disabled) |

## Child example

See [`examples/keel-lambda-host/.github/workflows/ci.yml`](examples/keel-lambda-host/.github/workflows/ci.yml).

## Layout

```text
config/regions.json
config/infra.json
.github/workflows/reusable-regions.yml
.github/workflows/reusable-build.yml
.github/workflows/reusable-deploy.yml
.github/workflows/reusable-pipeline.yml
scripts/build.sh
scripts/dev-deploy.sh
```
