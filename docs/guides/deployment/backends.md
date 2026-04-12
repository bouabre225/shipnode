# Deploy Backends

Deploy Express, NestJS, Fastify, Koa, Hono, AdonisJS, and other Node.js backends.

## Configuration

Create `shipnode.conf` with:

```bash
APP_TYPE=backend
SSH_USER=root
SSH_HOST=your-server-ip
SSH_PORT=22
REMOTE_PATH=/var/www/yourapp
PM2_APP_NAME=yourapp
BACKEND_PORT=3000
DOMAIN=api.yourdomain.com
```

## Add a Health Check Endpoint

ShipNode requires a `/health` endpoint for health checks:

```javascript
// Express
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Fastify
fastify.get('/health', async (req, res) => {
  return { status: 'ok' };
});

// NestJS (using @nestjs/terminus)
@Get('health')
@HealthCheck()
healthCheck() { /* ... */ }
```

## Deploy

```bash
shipnode deploy
```

### What Happens

1. **Sync** - rsync copies your code (excluding `node_modules`, `.env`, `.git`)
2. **Install** - `npm install` on the server
3. **Build** - Runs `npm run build` if defined
4. **Switch** - Atomically updates the `current` symlink
5. **Reload** - PM2 gracefully reloads the app
6. **Health Check** - Tests `localhost:3000/health`

### Health Check Configuration

```bash
HEALTH_CHECK_ENABLED=true       # default: true
HEALTH_CHECK_PATH=/health       # default: /health
HEALTH_CHECK_TIMEOUT=30         # seconds per attempt
HEALTH_CHECK_RETRIES=3          # attempts before rollback
```

## Framework-Specific Notes

### NestJS with Prisma

ShipNode auto-detects NestJS and Prisma. Add to your pre-deploy hook:

```bash
npx prisma generate
npx prisma migrate deploy
```

### Next.js (SSR Mode)

```bash
APP_TYPE=backend
PM2_APP_NAME=myapp
BACKEND_PORT=3000
DOMAIN=yourdomain.com
```

Make sure `next.config.js` has `output: 'standalone'`.

### AdonisJS

Default port is 3333. Update if needed:

```bash
BACKEND_PORT=3333
```

## Multi-Instance Deployment

For cluster mode, eject and customize the PM2 template:

```bash
shipnode eject pm2
```

Edit `.shipnode/templates/ecosystem.config.cjs`:

```javascript
module.exports = {
  apps: [{
    name: "{{APP_NAME}}",
    script: "{{INTERPRETER}}",
    args: "start",
    cwd: "{{REMOTE_PATH}}/current",
    instances: "max",
    exec_mode: "cluster",
  }]
};
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Health check fails | Verify `/health` endpoint: `curl localhost:3000/health` |
| Build fails | Check `package.json` has a `build` script |
| Port in use | Change `BACKEND_PORT` or kill the process |

See [Troubleshooting](../reference/troubleshooting.md) for more.
