# NestJS API Example

Minimal NestJS API demonstrating ShipNode deployment with Prisma.

## Features

- Health check endpoint (`/health`)
- TypeScript support
- Decorator-based routing
- Environment-based port configuration
- Prisma ORM integration

## Local Development

```bash
pnpm install
pnpm dev
```

Server runs on `http://localhost:3000`

## Project Structure

```
nestjs-api/
├── src/
│   ├── app.module.ts
│   └── main.ts           # NestJS bootstrap
├── prisma/
│   └── schema.prisma     # Database schema
├── package.json
├── shipnode.conf
└── README.md
```

## Code

```typescript
// src/main.ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  app.enableShutdownHooks();
  
  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`Server running on port ${port}`);
}
bootstrap();
```

## ShipNode Config

```bash
APP_TYPE=backend
SSH_USER=root
SSH_HOST=your-server-ip
REMOTE_PATH=/var/www/nestjs-api
PM2_APP_NAME=nestjs-api
BACKEND_PORT=3000
DOMAIN=api.yourdomain.com
```

## Pre-Deploy Hook

ShipNode auto-detects NestJS and Prisma. The pre-deploy hook runs:

```bash
npx prisma generate
npx prisma migrate deploy
```

## Deploy

```bash
shipnode deploy
```

## Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check (ShipNode monitoring)

## Next Steps

- [Configure Prisma with PostgreSQL](https://docs.shipnode.com/guides/configuration/database)
- [Set up environment variables](https://docs.shipnode.com/guides/environment-variables)
- [Add authentication](https://docs.shipnode.com/guides/security)
