# Supported Frameworks

ShipNode auto-detects these frameworks from your `package.json`.

## Backend Frameworks

| Framework | Port | Health Check | Notes |
|-----------|------|--------------|-------|
| Express | 3000 | `/health` | Most popular |
| NestJS | 3000 | `/api/health` | Use @nestjs/terminus |
| Fastify | 3000 | `/health` | Very fast |
| Koa | 3000 | `/health` | Lightweight |
| Hono | 3000 | `/health` | Edge-ready |
| Hapi | 3000 | `/health` | Enterprise |
| AdonisJS | 3333 | `/health` | Laravel-like |
| Feather | 3030 | `/health` | Real-time |

## Full-Stack Frameworks

| Framework | Port | Health Check | Notes |
|-----------|------|--------------|-------|
| Next.js (SSR) | 3000 | `/api/health` | Use `output: 'standalone'` |
| Nuxt | 3000 | `/api/health` | Vue full-stack |
| Remix | 3000 | `/healthcheck` | React full-stack |
| Astro | 4321 | `/api/health` | Island architecture |
| RedwoodJS | 8911 | `/api/health` | Full-stack |
| Blitz | 3000 | `/api/health` | Next.js alternative |

## Frontend Frameworks

| Framework | Build Output | SPA Routing | Notes |
|-----------|-------------|------------|-------|
| React | `dist/` or `build/` | Yes | Vite, CRA, Next.js |
| Vue | `dist/` | Yes | Vite, Nuxt |
| Svelte | `public/` | Yes | SvelteKit |
| Angular | `dist/` | Yes | Angular CLI |
| SolidJS | `dist/` | Yes | Vite |
| Ember | `dist/` | Yes | Ember CLI |
| Qwik | `dist/` | Yes | Qwik CLI |

## Framework Detection

ShipNode detects frameworks from dependencies:

```bash
# Express detection
npm install express

# NestJS detection
npm install @nestjs/core @nestjs/common

# Next.js detection
npm install next react react-dom
```

## Override Framework

Force a specific preset:

```bash
shipnode init --template express
```

Available templates:
- `express`
- `nestjs`
- `fastify`
- `nextjs`
- `nuxt`
- `remix`
- `astro`
- `react`
- `vue`
- `svelte`
- `angular`

## Custom Port

Override auto-detected port:

```bash
BACKEND_PORT=8080
```

## Health Check Path

Override auto-detected health check:

```bash
HEALTH_CHECK_PATH=/api/ping
```

## No Framework?

ShipNode works with plain Node.js:

```bash
APP_TYPE=backend
PM2_APP_NAME=myapp
BACKEND_PORT=3000
```

Add a `/health` endpoint to your `index.js`:

```javascript
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});
```
