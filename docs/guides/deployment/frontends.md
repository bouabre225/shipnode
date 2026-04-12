# Deploy Frontends

Deploy React, Vue, Svelte, Angular, and other static SPAs.

## Configuration

Create `shipnode.conf` with:

```bash
APP_TYPE=frontend
SSH_USER=root
SSH_HOST=your-server-ip
SSH_PORT=22
REMOTE_PATH=/var/www/yourapp
DOMAIN=yourdomain.com
```

ShipNode auto-detects your build directory (`dist/`, `build/`, or `public/`).

## Deploy

```bash
shipnode deploy
```

### What Happens

1. **Build** - Runs `npm run build` locally
2. **Sync** - rsync copies the build output to the server
3. **Switch** - Atomically updates the `current` symlink
4. **Serve** - Caddy serves static files with SPA routing

### Skip Build

If your files are already built:

```bash
shipnode deploy --skip-build
```

## SPA Routing

Caddy is configured to handle Single Page App routing. All requests that don't match static files will be served `index.html`, enabling client-side routing.

## Caching

Caddy automatically caches static assets aggressively:
- `Cache-Control: max-age=31536000` for hashed files
- `Cache-Control: no-cache` for `index.html`

## Custom Build Directory

If your build output is in a non-standard location:

```bash
BUILD_DIR=output
```

## Frontend Frameworks

| Framework | Build Command | Output |
|-----------|--------------|--------|
| React (Vite) | `npm run build` | `dist/` |
| React (CRA) | `npm run build` | `build/` |
| Vue | `npm run build` | `dist/` |
| Svelte | `npm run build` | `public/` |
| Angular | `ng build` | `dist/` |
| SolidJS | `npm run build` | `dist/` |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails | Check `package.json` has a `build` script |
| 404 on refresh | SPA routing is handled automatically |
| Assets not loading | Check base path in your framework config |

See [Troubleshooting](../reference/troubleshooting.md) for more.
