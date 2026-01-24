# Next.js SSR Example

Next.js application with server-side rendering for ShipNode deployment.

## Features

- Server-side rendering (SSR)
- React Server Components
- Standalone output for deployment
- App Router (Next.js 14+)

## Local Development

```bash
pnpm install
pnpm dev
```

Server runs on `http://localhost:3000`

## Build

```bash
pnpm build
```

This creates a standalone build optimized for deployment.

## Deployment with ShipNode

```bash
shipnode deploy
```

The `shipnode.conf` configures this as a backend service (SSR) on port 3000.

## Configuration

- `next.config.js` uses `output: 'standalone'` for optimized deployment
- SSR requires backend configuration in ShipNode
