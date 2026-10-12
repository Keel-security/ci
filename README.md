# Keel CI (GitHub Actions)

Shared reusable workflows for all Keel child repositories.

## Stages

| Stage | Job | When |
|-------|-----|------|
| **build** | `build` | Every PR and push |
| **dev:deploy** | `dev-deploy` | Push to `main` / `master` / `develop`, or `workflow_dispatch` |

`dev:deploy` deploys the app to the AWS **dev** environment (Lambda via SST/OpenNext by default).

## Child repo setup

1. In the child repo, add [`.github/workflows/ci.yml`](examples/child-repo/.github/workflows/ci.yml) (see also [control-panel example](examples/control-panel/.github/workflows/ci.yml)).
2. Repo secrets:
   - `AWS_ROLE_ARN` — IAM role trusted for GitHub OIDC
   - `DATABASE_URL` — optional, for migrate/deploy
   - `KEEL_API_KEY` — optional app secret
3. App-specific deploy config stays in the child (`sst.config.ts`, etc.).

```yaml
jobs:
  pipeline:
    uses: Keel-security/ci/.github/workflows/reusable-pipeline.yml@main
    with:
      app_dir: "."
      node_version: "22"
      deploy_tool: "sst"
      sst_stage: "dev"
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `app_dir` | `.` | Path to build/deploy |
| `node_version` | `22` | Node version |
| `build_command` | _(auto)_ | Override; else `scripts/build.sh` detects npm/go/python |
| `deploy_tool` | `sst` | `sst` \| `sam` \| `custom` |
| `deploy_command` | | Required if `deploy_tool=custom` |
| `sst_stage` | `dev` | SST stage |
| `sst_path` | `.` | Dir with `sst.config.ts` (relative to `app_dir`) |
| `aws_region` | `us-east-1` | AWS region |
| `run_deploy` | _(auto)_ | `true` / `false` to force deploy on/off |

## Layout

```text
.github/workflows/reusable-pipeline.yml   # build + dev:deploy
scripts/build.sh
scripts/dev-deploy.sh
examples/child-repo/...
examples/control-panel/...
```

## Notes

- PRs never deploy unless `run_deploy: true`.
- Deploy job uses GitHub Environment `dev` (optional protection rules in the child or org).
- Pin the reusable workflow to a tag/SHA in production children (`@v1` once you tag releases).
