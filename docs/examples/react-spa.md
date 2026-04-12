# React SPA Example

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

## Project Structure

```
react-router-app/
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   └── routes/
│       ├── home.tsx
│       └── about.tsx
├── index.html
├── vite.config.ts
├── package.json
├── shipnode.conf
└── README.md
```

## React Router Setup

```typescript
// src/App.tsx
import { createBrowserRouter, RouterProvider } from 'react-router';
import { routes } from './routes';

const router = createBrowserRouter(routes);

export function App() {
  return <RouterProvider router={router} />;
}
```

## ShipNode Config

```bash
APP_TYPE=frontend
SSH_USER=root
SSH_HOST=your-server-ip
REMOTE_PATH=/var/www/react-app
DOMAIN=yourdomain.com
```

## Deploy

```bash
shipnode deploy
```

## SPA Routing

ShipNode configures Caddy to handle SPA routing:

- All requests go to `index.html`
- Client-side router handles the route
- No 404 errors on page refresh

## Build Output

ShipNode auto-detects build output directory:
- `dist/` (Vite default)
- `build/` (CRA default)
- `public/` (Svelte default)

## Next Steps

- [Deploy frontends](https://docs.shipnode.com/guides/deployment/frontends)
- [Configure custom domain](https://docs.shipnode.com/guides/configuration/custom-templates)
- [Set up CI/CD](https://docs.shipnode.com/guides/ci-cd)
