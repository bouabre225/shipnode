# Examples

Minimal example projects demonstrating ShipNode deployment.

## Available Examples

### Backend Examples

| Example | Framework | Description |
|---------|-----------|-------------|
| [Express API](./express-api.md) | Express.js | REST API with health check |
| [NestJS API](./nestjs-api.md) | NestJS | TypeScript API with Prisma |
| [Next.js App](./nextjs-app.md) | Next.js | SSR full-stack app |

### Frontend Examples

| Example | Framework | Description |
|---------|-----------|-------------|
| [React SPA](./react-spa.md) | React Router v7 | Single Page Application |

## Try an Example

```bash
# Clone ShipNode
git clone https://github.com/devalade/shipnode.git
cd shipnode

# Explore an example
cd examples/express-api

# Install dependencies
npm install

# Run locally
npm run dev

# Deploy (after configuring shipnode.conf)
shipnode deploy
```

## What's Included

Each example includes:
- Complete source code
- `package.json` with dependencies
- `shipnode.conf` configuration
- Step-by-step README

## Quick Deploy

All examples are ready to deploy:

```bash
cd examples/<example-name>
shipnode init    # configure your server
shipnode setup   # first time only
shipnode deploy  # deploy!
```
