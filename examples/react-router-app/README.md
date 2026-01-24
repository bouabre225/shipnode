# React Router v7 SPA Example

Single-page application using React Router v7 for ShipNode deployment.

## Features

- Client-side routing with React Router v7
- Vite for fast development and optimized builds
- TypeScript support
- Static frontend deployment

## Local Development

```bash
pnpm install
pnpm dev
```

Server runs on `http://localhost:5173`

## Build

```bash
pnpm build
```

This creates optimized static files in the `dist/` directory.

## Deployment with ShipNode

```bash
shipnode deploy
```

The `shipnode.conf` configures this as a frontend (static) application.

## Configuration

- Vite handles bundling and optimization
- Frontend apps are served as static files by ShipNode
- Perfect for SPAs with client-side routing
