# Quick Start

Deploy your first app in 5 minutes.

## Prerequisites

- ShipNode installed on your local machine
- SSH access to your server
- A Node.js project (backend or frontend)

## Step 1: Initialize

Navigate to your project and run:

```bash
cd /path/to/your/project
shipnode init
```

The interactive wizard will:
- Detect your framework (Express, NestJS, React, etc.)
- Ask for your server details
- Create `shipnode.conf` with your settings

Example session:

```
→ Detected framework: Express
→ SSH user: root
→ SSH host: 203.0.113.10
→ PM2 process name: myapp
→ Application port: 3000
→ Domain (optional): api.myapp.com
```

## Step 2: Setup Server (First Time Only)

Install Node.js, PM2, and Caddy on your server:

```bash
shipnode setup
```

This installs:
- **Node.js** - LTS version via NodeSource
- **PM2** - Process manager with auto-restart
- **Caddy** - Web server with automatic HTTPS

## Step 3: Deploy

```bash
shipnode deploy
```

ShipNode will:
- Sync your code to the server
- Install dependencies
- Build (if needed)
- Switch to the new release atomically
- Run a health check
- Enable HTTPS via Caddy/Let's Encrypt

## Step 4: Check Status

```bash
shipnode status
```

See your app's status, uptime, CPU, memory, and current release.

## Step 5: Done!

Your app is live at `https://your-domain.com` (or `http://ip:port` if no domain).

## What's Next?

- [Deploy a Backend](../guides/deployment/backends.md) - Express, NestJS, etc.
- [Deploy a Frontend](../guides/deployment/frontends.md) - React, Vue, Svelte
- [Zero-Downtime](../guides/deployment/zero-downtime.md) - How atomic deployments work
- [Rollbacks](../guides/deployment/rollbacks.md) - Revert if something goes wrong
