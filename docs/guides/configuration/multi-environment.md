# Multi-Environment Deployments

Deploy to staging, production, and other environments.

## Multiple Config Files

Create separate config files for each environment:

```
shipnode.conf           # production (default)
shipnode.staging.conf
shipnode.dev.conf
```

## Deploy to Environment

```bash
shipnode deploy                    # uses shipnode.conf
shipnode deploy --profile staging  # uses shipnode.staging.conf
shipnode deploy --profile dev      # uses shipnode.dev.conf
shipnode deploy --config my.conf   # uses custom config file
```

Run one-off commands against an environment:

```bash
shipnode run "node -v" --profile staging
shipnode run "npm run db:seed" --config shipnode.production.conf
shipnode run bash --tty --profile dev
```

## Profile Shorthand

`--profile staging` is shorthand for `--config shipnode.staging.conf`.

## Environment Variables

Different environments typically need different values:

### Production

```bash
APP_TYPE=backend
SSH_USER=deploy
SSH_HOST=api.yourapp.com
REMOTE_PATH=/var/www/prod
PM2_APP_NAME=yourapp-prod
BACKEND_PORT=3000
DOMAIN=api.yourapp.com
KEEP_RELEASES=10
```

### Staging

```bash
APP_TYPE=backend
SSH_USER=deploy
SSH_HOST=staging.yourapp.com
REMOTE_PATH=/var/www/staging
PM2_APP_NAME=yourapp-staging
BACKEND_PORT=3001
DOMAIN=staging.yourapp.com
KEEP_RELEASES=3
```

## GitHub Actions Integration

Use the same workflow with different configs:

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    steps:
      - name: Deploy to production
        if: github.ref == 'refs/heads/main'
        run: shipnode deploy --profile production
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Deploy to staging
        if: github.ref == 'refs/heads/develop'
        run: shipnode deploy --profile staging
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
```

## Environment Differences

| Aspect | Staging | Production |
|--------|---------|------------|
| Server | Smaller instance | Larger instance |
| Domain | `staging.example.com` | `api.example.com` |
| PM2 name | `app-staging` | `app` |
| Keep releases | 3 | 10 |
| Notifications | All | Errors only |
