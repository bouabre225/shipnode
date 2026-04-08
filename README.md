# ShipNode

Deploy Node.js apps to your own server with a single command. No Kubernetes, no Docker, no vendor lock-in.

```
shipnode init && shipnode deploy
```

## How It Works

ShipNode is a CLI tool that deploys your Node.js backend or static frontend to any Ubuntu/Debian server over SSH. It handles everything: building, syncing files, process management, reverse proxying, and HTTPS.

```
Your Laptop                    Your Server
─────────────                  ─────────────
shipnode deploy  ───rsync──▶   /var/www/myapp/
                                 ├── current/       ← active release (symlink)
                                 ├── releases/      ← timestamped versions
                                 ├── shared/.env    ← persistent config
                                 └── PM2 + Caddy    ← process + HTTPS
```

### What gets installed on your server

One command (`shipnode setup`) installs everything:

- **Node.js** - LTS version via NodeSource
- **PM2** - Process manager (auto-restart, crash recovery)
- **Caddy** - Web server with automatic HTTPS (Let's Encrypt)

### What happens on every deploy

**Backend (Express, NestJS, Next.js, AdonisJS, etc.):**

1. Syncs your code to the server via rsync (excludes `node_modules`, `.env`, `.git`)
2. Installs dependencies and builds on the server
3. Creates a timestamped release directory
4. Atomically switches a `current` symlink to the new release (zero downtime)
5. Reloads PM2 gracefully
6. Runs a health check against your `/health` endpoint
7. If the health check fails, automatically rolls back to the previous release

**Frontend (React, Vue, Svelte, etc.):**

1. Builds your app locally
2. Syncs the build output (`dist/`, `build/`, or `public/`) to the server
3. Atomically switches the symlink
4. Caddy serves the static files with SPA routing

### What ShipNode manages for you

| Component | Backend | Frontend |
|-----------|---------|----------|
| Process management | PM2 (auto-restart, crash recovery) | N/A (static files) |
| Web server | Caddy reverse proxy | Caddy static file server |
| HTTPS | Automatic via Caddy/Let's Encrypt | Automatic via Caddy/Let's Encrypt |
| Environments | `.env` symlinked to each release | N/A |
| Rollbacks | One command: `shipnode rollback` | One command: `shipnode rollback` |

## Features

- **Zero-downtime deployments** - Atomic symlink switching, never serve a broken build
- **Automatic rollback** - Health check fails? Instantly reverts to the last working release
- **Configurable templates** - Eject PM2 and Caddy configs for full customization
- **Rich status dashboard** - See uptime, CPU, memory, release history at a glance
- **Deployment tracking** - Every deploy records duration, git commit, health check timing
- **Security hardening** - One-command firewall, SSH hardening, fail2ban setup
- **CI/CD ready** - Generate GitHub Actions workflows with `shipnode ci github`
- **User provisioning** - Manage SSH users with `users.yml`
- **Pre/post deploy hooks** - Run migrations, clear caches, send notifications
- **Auto-detection** - Frameworks (Express, NestJS, Next.js, etc.) and package managers (npm, yarn, pnpm, bun)
- **Multi-environment** - Deploy to staging, production with `--config` or `--profile`
- **Zero dependencies** - Pure bash, runs anywhere

## Installation

```bash
curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
```

Or clone and run directly:

```bash
git clone https://github.com/devalade/shipnode.git
cd shipnode
./shipnode help
```

See [INSTALL.md](INSTALL.md) for details. Uninstall: `rm -rf ~/.shipnode`

## Quick Start

### 1. Init

```bash
cd /path/to/your/project
shipnode init
```

The interactive wizard auto-detects your framework, suggests defaults, and creates `shipnode.conf`:

```
╔════════════════════════════════════╗
║  ShipNode Interactive Setup        ║
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

### 2. Setup server (first time only)

```bash
shipnode setup
```

Installs Node.js, PM2, and Caddy on your server.

### 3. Deploy

```bash
shipnode deploy
```

Your app is live. That's it.

### 4. Check status

```bash
shipnode status
```

```
═══════════════════════════════════════
  Application Status
═══════════════════════════════════════

  App:        myapp (backend)
  URL:        https://api.myapp.com
  Server:     root@203.0.113.10:22

  PM2:
    Status:    ● online
    Uptime:    2d 14h 32m
    Restarts:  0
    Instances: 1
    CPU:       3.2%
    Memory:    128MB
    Port:      3000

  Release:
    Current:   20260408143022 (2 hours ago)
    Previous:  20260408120000

  Disk:
    Total:     48GB
    Used:      12GB (25%)
    Releases:  1.2GB (3 releases)

═══════════════════════════════════════
```

## Commands

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

## Zero-Downtime Deployments

ShipNode uses the same pattern as Capistrano: timestamped releases with an atomic symlink switch.

### Directory structure on your server

```
/var/www/myapp/
├── current -> releases/20260408143022/   ← always points to active release
├── releases/
│   ├── 20260408120000/                   ← previous release (for rollback)
│   └── 20260408143022/                   ← current release
├── shared/
│   ├── .env                              ← persistent env vars (symlinked into each release)
│   └── ecosystem.config.cjs              ← PM2 config
└── .shipnode/
    ├── releases.json                     ← deployment history with metadata
    └── deploy.lock                       ← prevents concurrent deploys
```

### Deployment lifecycle

```
  1. Acquire lock
  2. Create release directory    releases/20260408143022/
  3. rsync files                 your laptop → server
  4. Link shared .env            shared/.env → releases/.../ .env
  5. Install dependencies        npm install
  6. Build (if needed)           npm run build
  7. Run pre-deploy hook         migrations, cache warm, etc.
  8. Atomic symlink switch       current → releases/20260408143022/
  9. Reload PM2                  graceful reload, zero downtime
 10. Health check                GET localhost:3000/health (3 retries)
 11. Record release              timestamp, git commit, duration, health data
 12. Run post-deploy hook        notifications, cache clear, etc.
 13. Cleanup old releases        keep last 5 by default
 14. Release lock
```

If step 10 fails, ShipNode immediately:
- Switches symlink back to the previous release
- Reloads PM2
- Records the failed deployment

### Rollback

```bash
shipnode rollback       # previous release
shipnode rollback 2     # 2 releases back
shipnode releases       # see all releases first
```

### Deployment history

Every deployment is recorded in `.shipnode/releases.json` with rich metadata:

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

### Health checks

Add a `/health` endpoint to your backend:

```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});
```

Configure in `shipnode.conf`:

```bash
HEALTH_CHECK_ENABLED=true       # default: true
HEALTH_CHECK_PATH=/health       # default: /health
HEALTH_CHECK_TIMEOUT=30         # seconds per attempt (default: 30)
HEALTH_CHECK_RETRIES=3          # attempts before rollback (default: 3)
```

## Customizing Templates

ShipNode generates PM2 and Caddy configs automatically. For most projects, the defaults work great. But when you need cluster mode, custom headers, rate limiting, or memory limits, you can **eject** the configs and customize them.

### `shipnode eject`

```bash
shipnode eject            # eject PM2 + Caddy templates
shipnode eject pm2        # eject only PM2 template
shipnode eject caddy      # eject only Caddy template
```

This creates editable templates in `.shipnode/templates/`:

```
.shipnode/templates/
├── ecosystem.config.cjs    ← customize PM2: cluster mode, memory limits, env vars
└── Caddyfile.caddy         ← customize Caddy: headers, TLS, rate limiting, caching
```

Ejected templates are **preserved across deploys**. ShipNode will use your custom versions instead of the defaults.

### Template variables

Templates use `{{VAR}}` placeholders that ShipNode replaces on every deploy:

| Variable | Description |
|----------|-------------|
| `{{APP_NAME}}` | PM2 process name |
| `{{INTERPRETER}}` | Package manager (npm, yarn, pnpm, bun) |
| `{{REMOTE_PATH}}` | Deployment path on server |
| `{{BACKEND_PORT}}` | Application port |
| `{{DOMAIN}}` | Your domain name |
| `{{SERVE_PATH}}` | Path to static files (frontend) |

### Custom PM2 config example

After `shipnode eject pm2`, edit `.shipnode/templates/ecosystem.config.cjs`:

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

### Custom Caddy config example

After `shipnode eject caddy`, edit `.shipnode/templates/Caddyfile.caddy`:

```
{{DOMAIN}} {
    reverse_proxy localhost:{{BACKEND_PORT}}
    encode gzip

    # Custom rate limiting
    rate_limit {
        zone dynamic_zone {
            key    {remote_host}
            events 100
            window 1s
        }
    }

    # Custom headers
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

### How template resolution works

ShipNode looks for templates in this order:

1. `.shipnode/templates/ecosystem.config.cjs` (ejected, user-customized)
2. `ecosystem.config.cjs` in project root (user-provided)
3. Built-in defaults (auto-generated, used when no custom template exists)

To reset to defaults, just delete the ejected files:

```bash
rm .shipnode/templates/ecosystem.config.cjs
rm .shipnode/templates/Caddyfile.caddy
```

## Pre/Post Deploy Hooks

ShipNode auto-generates hook scripts in `.shipnode/` during `shipnode init`. These run on your server during deployment.

### Pre-deploy hook (`.shipnode/pre-deploy.sh`)

Runs **before** the new release goes live. If it fails, the deployment aborts and rolls back.

Use for: database migrations, Prisma generate, cache warming.

```bash
#!/bin/bash
# Auto-generated by shipnode init
# Available: RELEASE_PATH, REMOTE_PATH, PM2_APP_NAME, BACKEND_PORT, SHARED_ENV_PATH

set -e
source "$SHARED_ENV_PATH"  # load .env variables
cd "$RELEASE_PATH"

# Prisma migrations (auto-detected by shipnode init)
npx prisma generate
npx prisma migrate deploy
```

### Post-deploy hook (`.shipnode/post-deploy.sh`)

Runs **after** the deployment succeeds. If it fails, the deployment is still considered successful.

Use for: notifications, cache clearing, cleanup.

```bash
#!/bin/bash
# Auto-generated by shipnode init

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

## Configuration

### `shipnode.conf` reference

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
# ShipNode uses .shipnode/pre-deploy.sh and .shipnode/post-deploy.sh by default.
# Override paths here if needed:
# PRE_DEPLOY_SCRIPT=.shipnode/pre-deploy.sh
# POST_DEPLOY_SCRIPT=.shipnode/post-deploy.sh
```

### Multi-environment

Use different config files for different environments:

```bash
shipnode deploy                              # uses shipnode.conf (production)
shipnode deploy --profile staging            # uses shipnode.staging.conf
shipnode deploy --config shipnode.prod.conf  # uses custom config file
```

## Package Manager Support

ShipNode auto-detects your package manager from lockfiles:

| Lockfile | Package Manager |
|----------|----------------|
| `bun.lockb` or `bun.lock` | bun |
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| (none) | npm |

Override in `shipnode.conf`: `PKG_MANAGER=bun`

## Backend Examples

### Express API

```bash
# Project structure
myapi/
├── src/index.js
├── package.json
├── .env
└── shipnode.conf

# shipnode.conf
APP_TYPE=backend
SSH_USER=root
SSH_HOST=123.45.67.89
REMOTE_PATH=/var/www/myapi
PM2_APP_NAME=myapi
BACKEND_PORT=3000
DOMAIN=api.myapp.com

# Deploy
shipnode deploy
# → Live at https://api.myapp.com
```

### NestJS with Prisma

```bash
# shipnode init auto-detects NestJS and generates pre-deploy hook with:
# npx prisma generate && npx prisma migrate deploy

shipnode init     # wizard detects NestJS + Prisma
shipnode deploy   # builds, migrates, deploys
```

### Next.js (SSR)

```bash
# Next.js runs as a backend (Node.js server)
# Uses output: 'standalone' in next.config.js for optimized builds

APP_TYPE=backend
PM2_APP_NAME=mywebapp
BACKEND_PORT=3000
DOMAIN=myapp.com
```

## Frontend Examples

### React / Vue / Svelte SPA

```bash
APP_TYPE=frontend
SSH_USER=root
SSH_HOST=123.45.67.89
REMOTE_PATH=/var/www/myapp
DOMAIN=myapp.com

# ShipNode builds locally (npm run build), syncs dist/, Caddy serves it
shipnode deploy
# → Live at https://myapp.com with SPA routing + aggressive asset caching
```

### Skip build

```bash
shipnode deploy --skip-build    # deploy pre-built files
```

## Environment Variables

ShipNode does **not** sync your `.env` file automatically (for security). Upload it once:

```bash
# Zero-downtime: .env lives in shared/ and is symlinked into each release
scp .env root@server:/var/www/myapp/shared/.env

# Or use the env command
shipnode env
```

## Observability

### `shipnode status` - Application dashboard

Shows everything at a glance: PM2 status, uptime, CPU, memory, current release, disk usage.

```bash
shipnode status
```

### `shipnode metrics` - Real-time monitoring

Opens the PM2 monitoring dashboard over SSH. Shows live CPU, memory, and log streams.

```bash
shipnode metrics
# Press Ctrl+C to exit
```

### `shipnode logs` - Live log stream

```bash
shipnode logs          # stream PM2 logs
shipnode restart       # restart app
shipnode stop          # stop app
```

### `shipnode releases` - Release history

Lists all deployments with timestamps and status.

```bash
shipnode releases
```

### Deployment metadata

Every deployment records:
- **Duration** - how long the deploy took
- **Git commit** - which commit was deployed (from `git rev-parse --short HEAD`)
- **Health check** - pass/fail, attempts, response time in milliseconds
- **Previous release** - which version it replaced

## Security

### Server hardening

```bash
shipnode harden
```

Interactive wizard to:
- Disable SSH password authentication
- Disable root SSH login
- Change SSH port
- Enable UFW firewall (22, 80, 443 only)
- Install and configure fail2ban

All changes are **opt-in** - you choose what to apply.

### Security audit

```bash
shipnode doctor --security
```

Non-destructive check of: SSH config, firewall status, fail2ban, file permissions.

### Pre-flight checks

```bash
shipnode doctor
```

Validates your entire setup: local config, SSH connectivity, remote Node.js/PM2/Caddy, disk space.

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

## User Provisioning

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

All users get:
- SSH or password authentication
- Deployment directory access via ACLs
- PM2 management via passwordless sudo

## Supported Frameworks

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

Use `shipnode init --template <name>` to use a specific preset, or `shipnode init --list-templates` to see all options.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Cannot connect to server | `ssh -p 22 root@your-server` to test |
| PM2 not found | `shipnode setup` to install |
| Build failed | Check `package.json` has a `build` script |
| Port already in use | Change `BACKEND_PORT` or kill the process |
| Health check fails | Verify `/health` endpoint: `ssh root@server "curl localhost:3000/health"` |
| Deployment lock stuck | `shipnode unlock` |
| Gum installation fails | Install manually: `sudo apt install gum` |
| Framework not detected | Install `jq`, or select manually in wizard |

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

See [ARCHITECTURE.md](ARCHITECTURE.md) for module documentation.

## Contributing

ShipNode is intentionally simple. Contributions welcome for bug fixes and small improvements.

## License

MIT
