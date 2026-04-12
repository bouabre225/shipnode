# Next.js App Example

Next.js application with server-side rendering (SSR) for ShipNode deployment.

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

## Project Structure

```
nextjs-app/
├── src/
│   ├── app/
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── api/
│   │       └── health/
│   │           └── route.ts
├── next.config.js
├── package.json
├── shipnode.conf
└── README.md
```

## next.config.js

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
};

module.exports = nextConfig;
```

The `output: 'standalone'` creates a minimized build that can run without the full Next.js server.

## Health Check

```typescript
// src/app/api/health/route.ts
export async function GET() {
  return Response.json({ status: 'ok' });
}
```

## ShipNode Config

```bash
APP_TYPE=backend
SSH_USER=root
SSH_HOST=your-server-ip
REMOTE_PATH=/var/www/nextjs-app
PM2_APP_NAME=nextjs-app
BACKEND_PORT=3000
DOMAIN=yourdomain.com
```

## Deploy

```bash
shipnode deploy
```

## SSR vs Static

Next.js with `output: 'standalone'` runs as a Node.js server:

- **SSR routes** - Rendered on request
- **API routes** - Work as expected
- **Static routes** - Can be pre-rendered

## Next Steps

- [Deploy frontend](https://docs.shipnode.com/guides/deployment/frontends)
- [Configure environment variables](https://docs.shipnode.com/guides/environment-variables)
- [Set up CI/CD](https://docs.shipnode.com/guides/ci-cd)
