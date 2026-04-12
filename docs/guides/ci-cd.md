# CI/CD Integration

Automate deployments with GitHub Actions.

## Generate Workflow

```bash
shipnode ci github
```

This creates `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup ShipNode
        uses: devalade/shipnode-action@latest
        
      - name: Deploy
        run: shipnode deploy
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SHIPNODE_SSH_KEY }}
```

## Setup Secrets

Add these secrets to your GitHub repository:

| Secret | Description |
|--------|-------------|
| `SSH_PRIVATE_KEY` | Private key for SSH access |
| `SSH_HOST` | Server hostname/IP |
| `SSH_USER` | SSH username |

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
      - uses: devalade/shipnode-action@latest
      - run: shipnode deploy --profile production
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          SSH_HOST: ${{ secrets.SSH_HOST }}
          SSH_USER: ${{ secrets.SSH_USER }}
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
      - uses: devalade/shipnode-action@latest
      - run: shipnode deploy --profile staging
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_STAGING_KEY }}

  deploy-production:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: devalade/shipnode-action@latest
      - run: shipnode deploy --profile production
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PROD_KEY }}
```

## Sync All Config

Push your entire config including .env to secrets:

```bash
shipnode ci env-sync --all
```

This syncs:
- `shipnode.conf` → GitHub secrets
- `.env` → `SHIPNODE_ENV_FILE` (base64 encoded)

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
