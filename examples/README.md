# ShipNode Examples

Minimal example projects demonstrating ShipNode deployment for different frameworks.

## Available Examples

### Backend Examples

- **[express-api](./express-api/)** - Express.js REST API
- **[nestjs-api](./nestjs-api/)** - NestJS TypeScript API
- **[nextjs-app](./nextjs-app/)** - Next.js SSR application

### Frontend Examples

- **[react-router-app](./react-router-app/)** - React Router v7 SPA

## Quick Start

Each example includes:
- Complete source code
- `package.json` with dependencies
- `shipnode.conf` configuration
- Detailed README with instructions

To try an example:

```bash
cd examples/<example-name>
pnpm install
pnpm dev
```

## Deployment

All examples are ready to deploy with ShipNode:

```bash
cd examples/<example-name>
shipnode deploy
```

## Configuration

Each example includes a `shipnode.conf` file:

- **Backend apps** (`APP_TYPE=backend`): Express, NestJS, Next.js SSR
- **Frontend apps** (`APP_TYPE=frontend`): React Router SPA

## Notes

- Backend examples run on port 3000 by default
- Frontend apps are built and served as static files
- All examples are minimal - extend as needed for your use case
