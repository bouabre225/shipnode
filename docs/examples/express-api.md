# Express API Example

Minimal Express.js API demonstrating ShipNode deployment.

## Features

- Health check endpoint (`/health`)
- JSON API responses
- Environment-based port configuration

## Local Development

```bash
pnpm install
pnpm dev
```

Server runs on `http://localhost:3000`

## Project Structure

```
express-api/
├── src/
│   └── index.js        # Express app
├── package.json
├── shipnode.conf        # ShipNode config
└── README.md
```

## Code

```javascript
const express = require('express');
const app = express();

const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({ 
    message: 'Hello from Express!',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

## ShipNode Config

```bash
APP_TYPE=backend
SSH_USER=root
SSH_HOST=your-server-ip
REMOTE_PATH=/var/www/express-api
PM2_APP_NAME=express-api
BACKEND_PORT=3000
DOMAIN=api.yourdomain.com
```

## Deploy

```bash
shipnode deploy
```

## Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check (for ShipNode monitoring)

## Next Steps

- [Add database](https://docs.shipnode.com/guides/configuration/database)
- [Configure health checks](https://docs.shipnode.com/guides/health-checks)
- [Set up CI/CD](https://docs.shipnode.com/guides/ci-cd)
