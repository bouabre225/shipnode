# shipnode.conf Configuration

Complete reference for `shipnode.conf` options.

## Minimal Configuration

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

## All Options

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `APP_TYPE` | "backend" or "frontend" | `backend` |
| `SSH_USER` | SSH username | `root` |
| `SSH_HOST` | Server IP or hostname | `123.45.67.89` |
| `REMOTE_PATH` | Deploy path on server | `/var/www/myapp` |

### Backend-Specific (required for APP_TYPE=backend)

| Variable | Description | Default |
|----------|-------------|---------|
| `PM2_APP_NAME` | PM2 process name | - |
| `BACKEND_PORT` | Application port | `3000` |

### Frontend-Specific

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Domain for HTTPS | - |
| `BUILD_DIR` | Build output directory | `dist/`, `build/`, or `public/` |

### SSH Options

| Variable | Description | Default |
|----------|-------------|---------|
| `SSH_PORT` | SSH port | `22` |
| `SSH_KEY` | Path to SSH private key | `~/.ssh/id_rsa` |

### Node.js Options

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_VERSION` | Node.js version | `lts` |
| `PKG_MANAGER` | Override package manager | auto-detected |

### Zero-Downtime Options

| Variable | Description | Default |
|----------|-------------|---------|
| `ZERO_DOWNTIME` | Enable atomic deployments | `true` |
| `KEEP_RELEASES` | Releases to keep | `5` |

### Health Check Options

| Variable | Description | Default |
|----------|-------------|---------|
| `HEALTH_CHECK_ENABLED` | Enable health checks | `true` |
| `HEALTH_CHECK_PATH` | Health endpoint | `/health` |
| `HEALTH_CHECK_TIMEOUT` | Seconds per attempt | `30` |
| `HEALTH_CHECK_RETRIES` | Attempts before rollback | `3` |

### Hook Options

| Variable | Description |
|----------|-------------|
| `PRE_DEPLOY_SCRIPT` | Path to pre-deploy hook |
| `POST_DEPLOY_SCRIPT` | Path to post-deploy hook |

### Customization

```bash
PM2_INSTANCES=max              # Cluster mode (optional)
PM2_MAX_MEMORY=1G             # Max memory before restart
CADDY_ADDITIONAL_CONFIG=      # Extra Caddy directives
```

## Environment Variables in Config

shipnode.conf is sourced as bash, so you can use variables:

```bash
DOMAIN=api.$PROJECT_DOMAIN
REMOTE_PATH=/var/www/$PROJECT_NAME
```

## Multiple Environments

Use different config files:

```bash
shipnode deploy --config shipnode.staging.conf
shipnode deploy --profile production  # uses shipnode.production.conf
```
