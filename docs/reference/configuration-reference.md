# Configuration Reference

Complete `shipnode.conf` reference with all options.

## Minimal Examples

### Backend

```bash
APP_TYPE=backend
SSH_USER=root
SSH_HOST=123.45.67.89
REMOTE_PATH=/var/www/myapp
PM2_APP_NAME=myapp
BACKEND_PORT=3000
```

### Frontend

```bash
APP_TYPE=frontend
SSH_USER=root
SSH_HOST=123.45.67.89
REMOTE_PATH=/var/www/myapp
DOMAIN=myapp.com
```

## All Configuration Options

### Required

| Variable | Type | Description |
|----------|------|-------------|
| `APP_TYPE` | string | `backend` or `frontend` |
| `SSH_USER` | string | SSH username |
| `SSH_HOST` | string | Server IP or hostname |
| `REMOTE_PATH` | string | Deploy path on server |

### SSH

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SSH_PORT` | number | `22` | SSH port |
| `SSH_KEY` | string | `~/.ssh/id_rsa` | Path to SSH private key |

### Backend Options

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `PM2_APP_NAME` | string | - | PM2 process name |
| `BACKEND_PORT` | number | `3000` | Application port |

### Frontend Options

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `DOMAIN` | string | - | Domain for HTTPS |
| `BUILD_DIR` | string | auto | Build output directory |

### Node.js

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NODE_VERSION` | string | `lts` | Node.js version |
| `PKG_MANAGER` | string | auto | `npm`, `yarn`, `pnpm`, or `bun` |

### Zero-Downtime

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ZERO_DOWNTIME` | boolean | `true` | Enable atomic deployments |
| `KEEP_RELEASES` | number | `5` | Old releases to keep |

### Health Checks

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `HEALTH_CHECK_ENABLED` | boolean | `true` | Enable health checks |
| `HEALTH_CHECK_PATH` | string | `/health` | Health endpoint |
| `HEALTH_CHECK_TIMEOUT` | number | `30` | Seconds per attempt |
| `HEALTH_CHECK_RETRIES` | number | `3` | Attempts before rollback |

### Hooks

| Variable | Type | Description |
|----------|------|-------------|
| `PRE_DEPLOY_SCRIPT` | string | Path to pre-deploy hook |
| `POST_DEPLOY_SCRIPT` | string | Path to post-deploy hook |

### Advanced

| Variable | Type | Description |
|----------|------|-------------|
| `PM2_INSTANCES` | string | `max` for cluster mode |
| `PM2_MAX_MEMORY` | string | Memory limit (e.g., `1G`) |
| `CADDY_ADDITIONAL_CONFIG` | string | Extra Caddy directives |

## Environment Variables

shipnode.conf is sourced as bash:

```bash
PROJECT_NAME=myapp
DOMAIN=api.$PROJECT_NAME.com
REMOTE_PATH=/var/www/$PROJECT_NAME
```

## Multiple Environments

```
shipnode.conf           # production
shipnode.staging.conf   # staging
shipnode.dev.conf       # development
```

Deploy with:

```bash
shipnode deploy --profile staging
```
