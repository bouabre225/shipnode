# CI/CD Integration

Automate deployments with GitHub Actions.

## Generate Workflow

```bash
shipnode ci github
```

This creates `.github/workflows/shipnode-deploy.yml`:

```yaml
name: Deploy with ShipNode

on:
  push:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
      - name: Deploy
        run: shipnode --config shipnode.ci.conf deploy
```

## Setup Secrets

Add these secrets to your GitHub repository:

| Secret | Description |
|--------|-------------|
| `SHIPNODE_SSH_KEY` | Private key for SSH access |
| `SHIPNODE_SSH_HOST` | Server hostname/IP |
| `SHIPNODE_SSH_USER` | SSH username |
| `SHIPNODE_SSH_PORT` | SSH port, usually `22` |
| `SHIPNODE_KNOWN_HOSTS` | Output of `ssh-keyscan -H your-host` (recommended) |

### Add Secret via CLI

```bash
shipnode ci env-sync
```

Or manually:

1. Go to your repo → Settings → Secrets
2. Add each secret

## Full Workflow Example

```yaml
name: Deploy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
      - run: shipnode --config shipnode.ci.conf deploy
```

## Multi-Environment

```yaml
name: Deploy

on:
  push:
    branches:
      - main      # production
      - develop   # staging

jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
      - run: shipnode --config shipnode.staging.conf deploy

  deploy-production:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
      - run: shipnode --config shipnode.production.conf deploy
```

## Sync All Config

Push your entire config including .env to secrets:

```bash
shipnode ci env-sync --all
```

This syncs:
- SSH connection values from `shipnode.conf` → GitHub secrets
- `.env` values → GitHub secrets

## Manual Deployment

For manual deploys without CI:

```bash
shipnode deploy
```

Or with specific config:

```bash
shipnode deploy --profile production
```

## Rollback via CI

If you need to rollback but can't SSH:

```bash
# Locally
shipnode rollback

# Or push a revert commit
git revert HEAD
git push
```
