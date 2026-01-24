# NestJS API Example

Minimal NestJS API demonstrating ShipNode deployment.

## Features

- Health check endpoint (`/health`)
- TypeScript support
- Decorator-based routing
- Environment-based port configuration

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

## Deployment with ShipNode

```bash
shipnode deploy
```

The `shipnode.conf` configures this as a backend service on port 3000.

## Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check
