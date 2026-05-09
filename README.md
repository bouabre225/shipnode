# ShipNode

Deploy Node.js apps to your own server with a single command. No Kubernetes, no Docker, no vendor lock-in.

```bash
shipnode init && shipnode deploy
```

## How It Works

ShipNode deploys your Node.js backend or static frontend to any Ubuntu/Debian server over SSH. It handles building, syncing files, process management, reverse proxying, and HTTPS.

```
Your Laptop                    Your Server
──────────────                  ────────────
shipnode deploy  ───rsync──▶   /var/www/myapp/
                                 ├── current/       ← active release (symlink)
                                 ├── releases/      ← timestamped versions
                                 ├── shared/.env    ← persistent config
                                 └── PM2 + Caddy    ← process + HTTPS
```

**What gets installed on your server** (`shipnode setup`):

- **Node.js** - LTS version via NodeSource
- **PM2** - Process manager (auto-restart, crash recovery)
- **Caddy** - Web server with automatic HTTPS (Let's Encrypt)
- **Databases** - optional PostgreSQL, MySQL, SQLite, and Redis setup when enabled

---

## Getting Started

### 1. Install

```bash
curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh -o shipnode-installer.sh && bash shipnode-installer.sh
```

Or clone and run directly:

```bash
git clone https://github.com/devalade/shipnode.git
cd shipnode
./shipnode help
```

See [Installation](docs/getting-started/installation.md) for details. Uninstall: `rm -rf ~/.shipnode`

### Optional: Install the AI Deployment Skill

ShipNode includes a shareable AI agent skill that helps users plan deployments, write `shipnode.conf`, troubleshoot failed deploys, manage `.env`, roll back releases, and set up CI/CD.

Install it with the [`skills` CLI](https://skills.sh/docs):

```bash
npx skills add devalade/shipnode
```

After installing, ask your agent to use `$shipnode` when you want help deploying a Node.js app with ShipNode.

### 2. Init

```bash
cd /path/to/your/project
shipnode init
```

The interactive wizard auto-detects your framework, suggests defaults, and creates `shipnode.conf`:

```
╔════════════════════════════════════╗
║  ShipNode Interactive Setup          ║
╚════════════════════════════════════╝

→ Detected framework: Express
→ Suggested app type: backend

Application type:
  1) Backend (Node.js API with PM2)
  2) Frontend (Static site)

Choose [1-2] (detected: backend): 
SSH user [root]: 
SSH host (IP or hostname): 203.0.113.10
SSH port [22]: 
Remote deployment path [/var/www/myapp]: 
PM2 process name [myapp]: 
Application port [3000]: 
Domain (optional): api.myapp.com

════════════════════════════════════
Configuration Summary
════════════════════════════════════
App Type:      backend
SSH:           root@203.0.113.10:22
Remote Path:   /var/www/myapp
PM2 Name:      myapp
Backend Port:  3000
Domain:        api.myapp.com
Zero-downtime: true
Health Checks: /health (30s timeout, 3 retries)
════════════════════════════════════

Create shipnode.conf with these settings? (Y/n): 
```

Non-interactive mode for scripts/CI:

```bash
shipnode init --non-interactive
```

### 3. Setup Server

```bash
shipnode setup
```

Installs Node.js, PM2, and Caddy on your server. Run once per server.

### 4. Deploy

```bash
shipnode deploy
```

Your app is live. That's it.

### 5. Check Status

```bash
shipnode status
```

---

## Deploy a Backend

Deploy Express, NestJS, Next.js, AdonisJS, or any Node.js backend.

### Prerequisites

- Add a `/health` endpoint to your app:

```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});
```

### Deploy

```bash
shipnode deploy
```

**What happens:**

1. Syncs code via rsync (excludes `node_modules`, `.env`, `.git`)
2. Installs dependencies and builds on the server
3. Creates a timestamped release directory
4. Atomically switches `current` symlink to new release (zero downtime)
5. Reloads PM2 gracefully
6. Runs a health check against `/health`
7. On failure: automatically rolls back to previous release

### Health Check Configuration

```bash
HEALTH_CHECK_ENABLED=true       # default: true
HEALTH_CHECK_PATH=/health       # default: /health
HEALTH_CHECK_TIMEOUT=30         # seconds per attempt (default: 30)
HEALTH_CHECK_RETRIES=3          # attempts before rollback (default: 3)
```

---

## Deploy a Frontend

Deploy React, Vue, Svelte, or any static SPA.

### Configuration

```bash
APP_TYPE=frontend
SSH_USER=root
SSH_HOST=123.45.67.89
REMOTE_PATH=/var/www/myapp
DOMAIN=myapp.com
```

### Deploy

```bash
shipnode deploy
```

**What happens:**

1. Builds your app locally (`npm run build`)
2. Syncs the build output (`dist/`, `build/`, or `public/`) to the server
3. Atomically switches the symlink
4. Caddy serves static files with SPA routing and aggressive caching

Skip the build step if files are pre-built:

```bash
shipnode deploy --skip-build
```

---

## Rollback

If a deployment fails health checks or you need to revert:

```bash
shipnode rollback           # previous release
shipnode rollback 2         # 2 releases back
shipnode releases           # see all releases first
```

### Directory Structure

```
/var/www/myapp/
├── current -> releases/20260408143022/   ← always points to active release
├── releases/
│   ├── 20260408120000/                   ← previous release (for rollback)
│   └── 20260408143022/                   ← current release
├── shared/
│   ├── .env                              ← persistent env vars
│   └── ecosystem.config.cjs              ← PM2 config
└── .shipnode/
    ├── releases.json                     ← deployment history
    └── deploy.lock                       ← prevents concurrent deploys
```

---

## Multi-Environment Deployments

Use different config files for different environments:

```bash
shipnode deploy                              # uses shipnode.conf (production)
shipnode deploy --profile staging            # uses shipnode.staging.conf
shipnode deploy --config shipnode.prod.conf  # uses custom config file
```

---

## Zero-Downtime Deployments

ShipNode uses timestamped releases with atomic symlink switching (same pattern as Capistrano).

### Deployment Lifecycle

```
 1. Acquire lock
 2. Create release directory    releases/20260408143022/
 3. rsync files                 laptop → server
 4. Link shared .env            shared/.env → releases/.../ .env
 5. Install dependencies        npm install
 6. Build (if needed)           npm run build
 7. Run pre-deploy hook         migrations, cache warm, etc.
 8. Atomic symlink switch       current → releases/20260408143022/
 9. Reload PM2                  graceful reload, zero downtime
10. Health check                GET localhost:3000/health (3 retries)
11. Record release              timestamp, git commit, duration
12. Run post-deploy hook        notifications, cache clear, etc.
13. Cleanup old releases        keep last 5 by default
14. Release lock
```

If step 10 fails, ShipNode immediately reverts to the previous release.

### Deployment History

Every deployment is recorded in `.shipnode/releases.json`:

```json
{
  "timestamp": "20260408143022",
  "date": "2026-04-08T14:30:22Z",
  "status": "success",
  "duration_seconds": 45,
  "commit": "abc1234",
  "previous_release": "20260408120000",
  "health_check": {
    "passed": true,
    "attempts": 1,
    "response_time_ms": 23
  }
}
```

---

## Customization

### Eject Templates

ShipNode generates PM2 and Caddy configs automatically. Eject to customize:

```bash
shipnode eject            # eject PM2 + Caddy templates
shipnode eject pm2        # eject only PM2 template
shipnode eject caddy      # eject only Caddy template
```

This creates editable templates in `.shipnode/templates/`:

```
.shipnode/templates/
├── ecosystem.config.cjs    ← customize PM2: cluster mode, memory limits
└── Caddyfile.caddy         ← customize Caddy: headers, TLS, rate limiting
```

Ejected templates are **preserved across deploys**.

### Template Variables

Templates use `{{VAR}}` placeholders replaced on every deploy:

| Variable | Description |
|----------|-------------|
| `{{APP_NAME}}` | PM2 process name |
| `{{INTERPRETER}}` | Package manager (npm, yarn, pnpm, bun) |
| `{{REMOTE_PATH}}` | Deployment path on server |
| `{{BACKEND_PORT}}` | Application port |
| `{{DOMAIN}}` | Your domain name |
| `{{SERVE_PATH}}` | Path to static files (frontend) |

### Custom PM2 Example

```javascript
module.exports = {
  apps: [{
    name: "{{APP_NAME}}",
    script: "{{INTERPRETER}}",
    args: "start",
    cwd: "{{REMOTE_PATH}}/current",
    instances: "max",              // use all CPU cores
    exec_mode: "cluster",          // enable cluster mode
    max_memory_restart: "1G",      // restart if memory exceeds 1GB
    env: {
      NODE_ENV: "production",
      PORT: {{BACKEND_PORT}}
    }
  }]
};
```

### Custom Caddy Example

```
{{DOMAIN}} {
    reverse_proxy localhost:{{BACKEND_PORT}}
    encode gzip

    rate_limit {
        zone dynamic_zone {
            key    {remote_host}
            events 100
            window 1s
        }
    }

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }

    log {
        output file /var/log/caddy/{{APP_NAME}}.log
        format json
    }
}
```

### Reset to Defaults

```bash
rm .shipnode/templates/ecosystem.config.cjs
rm .shipnode/templates/Caddyfile.caddy
```

---

## Hooks

### Pre-Deploy Hook

Runs **before** the new release goes live. If it fails, deployment aborts and rolls back.

```bash
#!/bin/bash
# Available: RELEASE_PATH, REMOTE_PATH, PM2_APP_NAME, BACKEND_PORT, SHARED_ENV_PATH

set -e
source "$SHARED_ENV_PATH"  # load .env variables
cd "$RELEASE_PATH"

# Prisma migrations (auto-detected by shipnode init)
npx prisma generate
npx prisma migrate deploy
```

### Post-Deploy Hook

Runs **after** deployment succeeds. Failures don't affect deployment status.

```bash
#!/bin/bash

set -e
source "$SHARED_ENV_PATH"

# Send Slack notification
curl -X POST "$SLACK_WEBHOOK" \
  -H 'Content-Type: application/json' \
  -d "{\"text\":\"Deployment of $PM2_APP_NAME completed\"}"

# Clear application cache
cd "$RELEASE_PATH"
npm run cache:clear
```

---

## Environment Variables

ShipNode does **not** sync your `.env` file automatically (for security). Upload it once:

```bash
scp .env root@server:/var/www/myapp/shared/.env

# Or use the env command
shipnode env
```

---

## User Management

Manage server users with `users.yml`:

```yaml
users:
  - username: alice
    email: alice@company.com
    password: "$6$rounds=5000$..."     # generate with: shipnode mkpasswd

  - username: bob
    email: bob@company.com
    authorized_key: "ssh-ed25519 AAAAC3... bob@laptop"
    sudo: true
```

```bash
shipnode user sync           # create users on server
shipnode user list           # show all users
shipnode user remove bob     # revoke access
shipnode mkpasswd            # generate password hash
```

---

## Security

### Server Hardening

```bash
shipnode harden
```

Interactive wizard to:

- Disable SSH password authentication
- Disable root SSH login
- Change SSH port
- Enable UFW firewall (22, 80, 443 only)
- Install and configure fail2ban

### Security Audit

```bash
shipnode doctor --security
```

Non-destructive check of: SSH config, firewall status, fail2ban, file permissions.

---

## CI/CD Integration

### GitHub Actions

```bash
# Generate workflow file
shipnode ci github

# Sync secrets (SSH_HOST, SSH_USER, SSH_PORT, SSH_PRIVATE_KEY)
shipnode ci env-sync --all

# Push and you're done
git add .github/workflows/deploy.yml
git commit -m "Add deployment workflow"
git push
```

---

## Reference

### All Commands

```bash
# Setup
shipnode init                          # Interactive config wizard
shipnode init --non-interactive        # Non-interactive (for CI/CD)
shipnode init --template express       # Use framework preset
shipnode init --print                  # Print config without writing
shipnode setup                         # Install Node.js, PM2, Caddy on server

# Deploy
shipnode deploy                        # Deploy your app
shipnode deploy --skip-build           # Skip build step
shipnode deploy --dry-run              # Preview without deploying

# Monitor
shipnode status                        # Rich status dashboard
shipnode logs                          # Stream live PM2 logs
shipnode metrics                       # Real-time CPU/memory monitor
shipnode releases                      # List all releases with history

# Manage
shipnode rollback                      # Rollback to previous release
shipnode rollback 2                    # Rollback 2 releases back
shipnode restart                       # Restart app (graceful)
shipnode stop                          # Stop app
shipnode unlock                        # Clear stuck deployment lock

# Customize
shipnode eject                         # Eject PM2 + Caddy templates
shipnode eject pm2                     # Eject only PM2 template
shipnode eject caddy                   # Eject only Caddy template
shipnode config                        # Show resolved config values
shipnode config validate               # Validate config without deploying

# Environment
shipnode env                           # Upload .env to server

# Diagnostics
shipnode doctor                        # Pre-flight checks
shipnode doctor --security             # Security audit
shipnode harden                        # Server hardening wizard

# CI/CD
shipnode ci github                     # Generate GitHub Actions workflow
shipnode ci env-sync                   # Sync config to GitHub secrets
shipnode ci env-sync --all             # Sync config + .env to secrets

# User Management
shipnode user sync                     # Provision users from users.yml
shipnode user list                     # List provisioned users
shipnode user remove <user>            # Revoke user access
shipnode mkpasswd                      # Generate password hash

# Multi-environment
shipnode deploy --config shipnode.staging.conf   # Custom config
shipnode deploy --profile staging                # Shorthand: shipnode.staging.conf
```

### Configuration Reference

```bash
# === Required ===
APP_TYPE=backend             # "backend" or "frontend"
SSH_USER=root                # SSH user for connecting to server
SSH_HOST=123.45.67.89        # Server IP or hostname
REMOTE_PATH=/var/www/app     # Where your app lives on the server

# === Optional ===
SSH_PORT=22                  # SSH port (default: 22)
NODE_VERSION=lts             # Node.js version for setup (default: lts)
DOMAIN=myapp.com             # Domain for automatic HTTPS via Caddy
PKG_MANAGER=                 # Override auto-detection (npm, yarn, pnpm, bun)

# === Backend-specific (required if APP_TYPE=backend) ===
PM2_APP_NAME=myapp           # PM2 process name
BACKEND_PORT=3000            # Port your app listens on

# === Zero-downtime deployment ===
ZERO_DOWNTIME=true           # Enable atomic deployments (default: true)
KEEP_RELEASES=5              # How many old releases to keep (default: 5)

# === Health checks (backend only) ===
HEALTH_CHECK_ENABLED=true    # Enable health checks (default: true)
HEALTH_CHECK_PATH=/health    # Endpoint to check (default: /health)
HEALTH_CHECK_TIMEOUT=30      # Seconds per attempt (default: 30)
HEALTH_CHECK_RETRIES=3       # Attempts before rollback (default: 3)

# === Hooks ===
# PRE_DEPLOY_SCRIPT=.shipnode/pre-deploy.sh
# POST_DEPLOY_SCRIPT=.shipnode/post-deploy.sh

# === Database and Redis setup ===
DB_SETUP_ENABLED=false       # Set true to install/configure DB during setup
DB_TYPE=postgresql           # postgresql, mysql, or sqlite
DB_NAME=myapp_db             # PostgreSQL/MySQL database to create
DB_USER=myapp_user           # PostgreSQL/MySQL user to create
DB_PASSWORD=${DB_PASSWORD:-} # PostgreSQL/MySQL password from env or .env
DB_SQLITE_PATH=              # Optional; defaults to $REMOTE_PATH/shared/database.sqlite
REDIS_SETUP_ENABLED=false    # Set true to install/configure Redis on localhost

# === Database backups to S3 ===
DB_BACKUP_ENABLED=false      # Set true to configure scheduled backups
DB_BACKUP_S3_BUCKET=         # S3 bucket for uploaded backup files
DB_BACKUP_S3_PREFIX=myapp    # Optional path prefix inside the bucket
DB_BACKUP_SCHEDULE=daily     # hourly, daily, weekly, or systemd OnCalendar
DB_BACKUP_RETENTION_DAYS=14  # Local compressed backup retention
DB_BACKUP_S3_ENDPOINT=       # Optional S3-compatible endpoint
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
AWS_DEFAULT_REGION=eu-west-1
```

### Database Backups

ShipNode can install a small remote backup script and a systemd timer that dumps the configured PostgreSQL, MySQL, or SQLite database, compresses it, and uploads it to S3.

```bash
DB_BACKUP_ENABLED=true
DB_BACKUP_S3_BUCKET=my-backups
DB_BACKUP_S3_PREFIX=myapp/production
DB_BACKUP_SCHEDULE=daily
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
AWS_DEFAULT_REGION=eu-west-1
```

Put real AWS/S3 credentials in `.env`, upload them with `shipnode env`, then configure backups:

```bash
shipnode setup
shipnode backup setup
shipnode backup run
shipnode backup status
```

Use `DB_BACKUP_S3_ENDPOINT` for S3-compatible storage such as Cloudflare R2, MinIO, or DigitalOcean Spaces. `DB_BACKUP_RETENTION_DAYS` controls local compressed files on the server; use your bucket lifecycle policy for S3 retention.

### Supported Frameworks

Auto-detected from your `package.json`:

| Framework | Type | Port | Health Check |
|-----------|------|------|-------------|
| Express | Backend | 3000 | `/health` |
| NestJS | Backend | 3000 | `/api/health` |
| Fastify | Backend | 3000 | `/health` |
| Koa | Backend | 3000 | `/health` |
| Hono | Backend | 3000 | `/health` |
| AdonisJS | Backend | 3333 | `/health` |
| Next.js | Backend (SSR) | 3000 | `/api/health` |
| Nuxt | Backend (SSR) | 3000 | `/api/health` |
| Remix | Backend | 3000 | `/healthcheck` |
| Astro | Backend/Frontend | 4321 | `/api/health` |
| React | Frontend | - | - |
| Vue | Frontend | - | - |
| Svelte | Frontend | - | - |
| Angular | Frontend | - | - |
| SolidJS | Frontend | - | - |

### Package Manager Support

Auto-detected from lockfiles:

| Lockfile | Package Manager |
|----------|----------------|
| `bun.lockb` or `bun.lock` | bun |
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| (none) | npm |

Override in `shipnode.conf`: `PKG_MANAGER=bun`

### Excluded Files

These are excluded from rsync by default:

- `node_modules/` - rebuilt on the server
- `.env`, `.env.*` - managed separately via `shipnode env`
- `.git/` - not needed in production
- `shipnode.conf`, `shipnode.*.conf` - contains server credentials
- `.shipnode/` - local hooks and templates
- `*.log` - log files

Customize with `.shipnodeignore` (like `.gitignore`).

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Cannot connect to server | `ssh -p 22 root@your-server` to test |
| PM2 not found | `shipnode setup` to install |
| Build failed | Check `package.json` has a `build` script |
| Port already in use | Change `BACKEND_PORT` or kill the process |
| Health check fails | Verify `/health` endpoint: `ssh root@server "curl localhost:3000/health"` |
| Deployment lock stuck | `shipnode unlock` |
| Gum installation fails | Interactive commands try to install Gum locally; install manually from https://github.com/charmbracelet/gum |
| Framework not detected | Install `jq`, or select manually in wizard |

---

## Comparison

| Feature | ShipNode | PM2 Deploy | Capistrano | Kamal |
|---------|----------|------------|------------|-------|
| Language | Bash | JS | Ruby | Ruby |
| Config files | 1 | 1 | Multiple | 1 |
| Zero-downtime | Built-in | Manual | Built-in | Built-in |
| Auto rollback | Yes | No | No | No |
| HTTPS | Automatic | Manual | Manual | Automatic |
| Frontend + Backend | Both | Backend | Backend | Both |
| Custom templates | Yes (eject) | Manual | Templates | No |
| Dependencies | None | Node.js | Ruby | Ruby + Docker |

---

## Documentation

For detailed guides and reference documentation, see the [docs/](docs/) folder:

- [Getting Started](docs/getting-started/) - Installation, quick start, first deploy
- [Guides](docs/guides/) - Deployment, configuration, hooks, security, CI/CD
- [Reference](docs/reference/) - Commands, frameworks, troubleshooting
- [Examples](docs/examples/) - Express, NestJS, Next.js, React examples
- [Advanced](docs/advanced/) - Architecture, contributing, distribution

---

## Project Structure

```
shipnode/
├── shipnode                          # Main entry point
├── lib/
│   ├── core.sh                       # Logging, template rendering
│   ├── pkg-manager.sh                # Package manager detection
│   ├── release.sh                    # Zero-downtime release management
│   ├── framework.sh                  # Framework auto-detection
│   ├── validation.sh                 # Input validation
│   ├── prompts.sh                    # Interactive UI (Gum)
│   └── commands/
│       ├── init.sh                   # shipnode init
│       ├── setup.sh                  # shipnode setup
│       ├── deploy.sh                 # shipnode deploy
│       ├── status.sh                 # shipnode status (dashboard)
│       ├── rollback.sh               # shipnode rollback
│       ├── eject.sh                  # shipnode eject (templates)
│       ├── metrics.sh                # shipnode metrics
│       ├── config-cmd.sh             # shipnode config
│       ├── doctor.sh                 # shipnode doctor
│       ├── harden.sh                 # shipnode harden
│       ├── ci.sh                     # shipnode ci
│       └── ...
├── templates/
│   ├── ecosystem.config.cjs.tmpl     # PM2 template (for eject)
│   ├── Caddyfile.backend.tmpl        # Caddy backend template (for eject)
│   ├── Caddyfile.frontend.tmpl       # Caddy frontend template (for eject)
│   ├── pre-deploy.sh.template        # Pre-deploy hook template
│   └── post-deploy.sh.template       # Post-deploy hook template
├── examples/
│   ├── express-api/
│   ├── nestjs-api/
│   ├── nextjs-app/
│   └── react-router-app/
└── build.sh                          # Bundle into single file
```

See [Architecture](docs/advanced/architecture.md) for module documentation.

---

## Contributing

ShipNode is intentionally simple. Contributions welcome for bug fixes and small improvements.

## License

MIT
