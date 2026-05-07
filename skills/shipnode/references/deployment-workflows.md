# Deployment Workflows

## First Deploy Checklist

Prerequisites:

- Ubuntu/Debian server with SSH access.
- Ports 80 and 443 open when using a domain and Caddy HTTPS.
- Port 22 or custom SSH port open.
- DNS A/AAAA record pointed at the server when using a domain.
- Local Node.js project with `package.json`.

Recommended flow:

```bash
shipnode init
shipnode setup
shipnode env      # if the app needs .env secrets
shipnode deploy
shipnode status
```

`shipnode setup` installs Node.js, PM2, and Caddy on the server. Run it once per server or after significant server changes.

## Backend/API Deployments

Use for Express, NestJS, Fastify, Koa, Hono, AdonisJS, Next.js SSR, and other long-running Node.js servers.

Minimal `shipnode.conf`:

```bash
APP_TYPE=backend
SSH_USER=root
SSH_HOST=your-server-ip
SSH_PORT=22
REMOTE_PATH=/var/www/yourapp
PM2_APP_NAME=yourapp
BACKEND_PORT=3000
DOMAIN=api.example.com
```

Backend deploy flow:

1. Sync code to a timestamped release, excluding `node_modules`, `.env`, and `.git`.
2. Install dependencies on the server.
3. Run the build script when present.
4. Link shared `.env` into the release.
5. Switch `current` symlink.
6. Reload PM2.
7. Check `http://localhost:$BACKEND_PORT$HEALTH_CHECK_PATH`.
8. Roll back automatically if health checks fail.

Add a health endpoint before the first deploy:

```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});
```

Health check config:

```bash
HEALTH_CHECK_ENABLED=true
HEALTH_CHECK_PATH=/health
HEALTH_CHECK_TIMEOUT=30
HEALTH_CHECK_RETRIES=3
```

Framework notes:

- NestJS with Prisma: run `npx prisma generate` and `npx prisma migrate deploy` from a pre-deploy hook when needed.
- Next.js SSR: use `APP_TYPE=backend`, `BACKEND_PORT=3000`, and consider `output: 'standalone'`.
- AdonisJS often uses port `3333`; set `BACKEND_PORT=3333` when applicable.

## Static Frontend Deployments

Use for React, Vue, Svelte, Angular, Solid, and static SPA builds.

Minimal `shipnode.conf`:

```bash
APP_TYPE=frontend
SSH_USER=root
SSH_HOST=your-server-ip
SSH_PORT=22
REMOTE_PATH=/var/www/yourapp
DOMAIN=example.com
```

Frontend deploy flow:

1. Run local build with `npm run build` unless `--skip-build` is used.
2. Sync the build output to a timestamped release.
3. Switch `current` symlink.
4. Serve static files with Caddy and SPA routing.

Common build outputs:

- Vite React/Vue/Solid: `dist/`.
- Create React App: `build/`.
- Svelte: often `public/` or framework-specific output.
- Angular: `dist/`.

Set a custom output when auto-detection is wrong:

```bash
BUILD_DIR=output
```

## Package Managers

ShipNode can use npm, yarn, pnpm, or bun.

Detection order:

1. Valid `PKG_MANAGER` in `shipnode.conf`.
2. Lockfiles: `bun.lockb`, `pnpm-lock.yaml`, `yarn.lock`.
3. Default to npm.

Set explicitly when needed:

```bash
PKG_MANAGER=pnpm
```

## Useful Commands

```bash
shipnode config validate
shipnode doctor
shipnode deploy --dry-run
shipnode deploy --skip-build
shipnode deploy --profile staging
shipnode logs
shipnode status
```
