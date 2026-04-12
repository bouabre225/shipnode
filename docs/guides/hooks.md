# Pre/Post Deploy Hooks

Run scripts before and after deployment.

## Auto-Generated Hooks

ShipNode creates hooks during `shipnode init`:

```
.shipnode/
├── pre-deploy.sh
└── post-deploy.sh
```

## Pre-Deploy Hook

Runs **before** the new release goes live. If it fails, deployment aborts and rolls back.

```bash
#!/bin/bash
# Available variables:
# RELEASE_PATH, REMOTE_PATH, PM2_APP_NAME, BACKEND_PORT, SHARED_ENV_PATH

set -e
source "$SHARED_ENV_PATH"  # load .env variables
cd "$RELEASE_PATH"

# Prisma migrations
npx prisma generate
npx prisma migrate deploy

# Database migrations
npm run db:migrate

# Cache warming
npm run cache:warm
```

### Use Cases

- Database migrations
- Dependency updates
- Build steps
- Data validation
- Cache clearing

## Post-Deploy Hook

Runs **after** deployment succeeds. Failures don't affect deployment status.

```bash
#!/bin/bash
set -e
source "$SHARED_ENV_PATH"

# Slack notification
curl -X POST "$SLACK_WEBHOOK" \
  -H 'Content-Type: application/json' \
  -d "{\"text\":\"Deployed $PM2_APP_NAME successfully\"}"

# Clear CDN cache
curl -X POST "$CDN_PURGE_URL"

# Health check monitoring setup
curl -d "host=$DOMAIN" "$UPTIME_WEBHOOK"
```

### Use Cases

- Send notifications (Slack, email, PagerDuty)
- Update monitoring systems
- Clear CDN caches
- Trigger other deployments

## Configure Hook Paths

Override default locations in `shipnode.conf`:

```bash
PRE_DEPLOY_SCRIPT=.shipnode/my-pre-hook.sh
POST_DEPLOY_SCRIPT=.shipnode/my-post-hook.sh
```

## Hook Environment

Hooks run with these environment variables:

| Variable | Description |
|----------|-------------|
| `RELEASE_PATH` | Path to current release |
| `REMOTE_PATH` | Base deployment path |
| `PM2_APP_NAME` | PM2 process name |
| `BACKEND_PORT` | Application port |
| `SHARED_ENV_PATH` | Path to shared .env |
| `DOMAIN` | Configured domain |

## Debugging Hooks

Test hooks locally:

```bash
# Preview what would run
shipnode deploy --dry-run

# Check hook output
shipnode logs
```

## Hook Best Practices

1. **Idempotency** - Hooks should be safe to run multiple times
2. **Timeouts** - Set appropriate timeouts for long-running hooks
3. **Rollback** - Pre-deploy failures trigger automatic rollback
4. **Logging** - Log hook actions for debugging
5. **Notifications** - Use post-deploy for non-critical notifications
