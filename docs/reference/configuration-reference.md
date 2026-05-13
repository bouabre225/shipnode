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

### Cloudflare Easy Mode

```bash
APP_TYPE=backend
DOMAIN=app.example.com

SSH_USER=deploy
SSH_HOST=ssh.example.com
SSH_PORT=22
SSH_PROXY_MODE=cloudflare

REMOTE_PATH=/var/www/myapp
PM2_APP_NAME=myapp
BACKEND_PORT=3000

CLOUDFLARE_ENABLED=true
CLOUDFLARE_ZONE=example.com
CLOUDFLARE_LOCKDOWN_FIREWALL=true
CLOUDFLARE_ACCESS_EMAILS=you@example.com
```

Run `shipnode cloudflare init` with `CLOUDFLARE_API_TOKEN` exported in your shell. For first-time setup, if `ssh.example.com` is not reachable yet, export `SHIPNODE_BOOTSTRAP_SSH_HOST` temporarily; do not commit the origin IP.

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
| `SSH_PROXY_MODE` | string | `direct` | `direct` or `cloudflare` |
| `SSH_PROXY_COMMAND` | string | `cloudflared access ssh --hostname %h` | SSH ProxyCommand used when `SSH_PROXY_MODE=cloudflare` |

### Backend Options

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `PM2_APP_NAME` | string | - | PM2 process name |
| `BACKEND_PORT` | number | `3000` | Application port |

> **Required:** Your `package.json` must have a `start` script. ShipNode runs `npm start` (or `yarn start`, `pnpm start`, `bun start`) via PM2 to start your application. There is no `shipnode.conf` option to override the entry file — use your `package.json` `start` script or eject the PM2 template (`shipnode eject pm2`) for custom configurations.

### Frontend Options

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `DOMAIN` | string | - | Domain for HTTPS |
| `BUILD_DIR` | string | auto | Build output directory |

### Cloudflare Easy Mode

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CLOUDFLARE_ENABLED` | boolean | `false` | Enable Cloudflare setup commands |
| `CLOUDFLARE_ZONE` | string | - | Cloudflare zone, such as `example.com` |
| `CLOUDFLARE_APP_HOSTNAME` | string | `DOMAIN` | Public app hostname routed through Tunnel |
| `CLOUDFLARE_SSH_HOSTNAME` | string | `SSH_HOST` | SSH hostname routed through Tunnel and Access |
| `CLOUDFLARE_TUNNEL_NAME` | string | app path name | Tunnel name to create or reuse |
| `CLOUDFLARE_LOCKDOWN_FIREWALL` | boolean | `false` | Remove public UFW allows for 22/80/443 after Tunnel setup |
| `CLOUDFLARE_ACCESS_EMAILS` | string | - | Optional comma-separated emails for an Access allow policy |

Secrets:

```bash
export CLOUDFLARE_API_TOKEN=...
```

`shipnode cloudflare init` creates or reuses the Cloudflare Tunnel, adds DNS CNAME routes for the app and SSH hostnames, configures an SSH Access application, installs `cloudflared` on the server, and can lock down direct inbound web/SSH ports. Lockdown is skipped until an Access policy exists; set `CLOUDFLARE_ACCESS_EMAILS` for automatic email-based allow-listing.

See the full setup and API-token permission guide in [Cloudflare Easy Mode](../guides/cloudflare.md).

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

### Database and Redis Setup

When `DB_SETUP_ENABLED=true`, `shipnode setup` provisions the selected database on the remote server. `DB_TYPE` supports `postgresql`, `mysql`, and `sqlite`. PostgreSQL/MySQL setup creates the configured database and user. SQLite setup installs `sqlite3` and creates the database file. Redis is independent and enabled with `REDIS_SETUP_ENABLED=true`.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `DB_SETUP_ENABLED` | boolean | `false` | Enable database setup during `shipnode setup` |
| `DB_TYPE` | string | `postgresql` | `postgresql`, `mysql`, or `sqlite` |
| `DB_NAME` | string | - | PostgreSQL/MySQL database to create |
| `DB_USER` | string | - | PostgreSQL/MySQL database user to create |
| `DB_PASSWORD` | string | - | PostgreSQL/MySQL password for `DB_USER` |
| `DB_SQLITE_PATH` | string | `$REMOTE_PATH/shared/database.sqlite` | SQLite database path |
| `REDIS_SETUP_ENABLED` | boolean | `false` | Enable Redis setup during `shipnode setup` |

PostgreSQL/MySQL example:

```bash
DB_SETUP_ENABLED=true
DB_TYPE=postgresql
DB_NAME=myapp_db
DB_USER=myapp_user
DB_PASSWORD=${DB_PASSWORD:-}
```

SQLite example:

```bash
DB_SETUP_ENABLED=true
DB_TYPE=sqlite
DB_SQLITE_PATH=/var/www/myapp/shared/database.sqlite
```

Redis example:

```bash
REDIS_SETUP_ENABLED=true
```

Run schema migrations from `.shipnode/pre-deploy.sh`; database creation and migrations are separate steps.

Keep SQLite files under `shared/` so they survive release switches and cleanup. ShipNode rejects paths inside `$REMOTE_PATH/current/` or `$REMOTE_PATH/releases/`.

### Database Backups

When `DB_BACKUP_ENABLED=true`, `shipnode setup` and `shipnode backup setup` install a remote backup script at `$REMOTE_PATH/shared/shipnode-backup.sh` and enable a systemd timer. Backups are compressed locally, uploaded to S3, and can be run manually with `shipnode backup run`.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `DB_BACKUP_ENABLED` | boolean | `false` | Enable scheduled database backups |
| `DB_BACKUP_S3_BUCKET` | string | - | S3 bucket where backups are uploaded |
| `DB_BACKUP_S3_PREFIX` | string | app name | Optional S3 key prefix |
| `DB_BACKUP_SCHEDULE` | string | `daily` | `hourly`, `daily`, `weekly`, or a systemd `OnCalendar` value |
| `DB_BACKUP_RETENTION_DAYS` | number | `14` | Days to keep local compressed backups on the server |
| `DB_BACKUP_S3_ENDPOINT` | string | - | Optional S3-compatible endpoint |
| `AWS_ACCESS_KEY_ID` | string | - | S3 access key, preferably from `.env` |
| `AWS_SECRET_ACCESS_KEY` | string | - | S3 secret key, preferably from `.env` |
| `AWS_DEFAULT_REGION` | string | - | S3 region |

Example:

```bash
DB_BACKUP_ENABLED=true
DB_BACKUP_S3_BUCKET=my-backups
DB_BACKUP_S3_PREFIX=myapp/production
DB_BACKUP_SCHEDULE=daily
DB_BACKUP_RETENTION_DAYS=14
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
AWS_DEFAULT_REGION=eu-west-1
```

Store real credentials in `.env`, run `shipnode env`, then run `shipnode backup setup`. S3 object retention should be managed with bucket lifecycle rules; ShipNode only prunes local compressed files.

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
