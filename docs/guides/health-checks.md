# Health Checks

ShipNode monitors your deployment with HTTP health checks.

## How It Works

After each deployment, ShipNode:
1. Waits for the app to start
2. Makes an HTTP GET request to the health endpoint
3. Verifies the response is 2xx
4. Rolls back if check fails

## Required Endpoint

Add a `/health` endpoint to your backend:

```javascript
// Express
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Fastify
fastify.get('/health', async (req, res) => {
  res.send({ status: 'ok' });
});

// NestJS
@Get('health')
healthCheck() {
  return { status: 'ok' };
}
```

## Configuration

```bash
HEALTH_CHECK_ENABLED=true       # Enable (default: true)
HEALTH_CHECK_PATH=/health       # Endpoint (default: /health)
HEALTH_CHECK_TIMEOUT=30         # Seconds per attempt
HEALTH_CHECK_RETRIES=3         # Attempts before rollback
```

## Custom Health Check Path

```bash
HEALTH_CHECK_PATH=/api/health
```

## Disable Health Checks

```bash
HEALTH_CHECK_ENABLED=false
```

Not recommended - you won't have automatic rollback protection.

## Health Check Response

ShipNode expects:
- HTTP status 2xx
- Optional JSON body

### Valid Response Examples

```json
{ "status": "ok" }
{ "healthy": true }
{ "status": "ok", "version": "1.2.3" }
```

### Invalid Response Examples

```json
{ "error": "database connection failed" }  // 500 error
{ "status": "degraded" }                    // non-2xx
```

## Health Check Timing

```
Deployment complete
       ↓
Wait 1 second
       ↓
GET localhost:3000/health
       ↓
Success? → Deployment complete
       ↓
No
       ↓
Wait 1 second
       ↓
Retry (up to 3 times)
       ↓
All fail → Rollback
```

## Deep Health Checks

For more thorough checks (database, cache, external services):

```javascript
app.get('/health', async (req, res) => {
  try {
    await db.query('SELECT 1');
    await cache.ping();
    res.json({ 
      status: 'ok',
      database: 'connected',
      cache: 'connected'
    });
  } catch (err) {
    res.status(503).json({ 
      status: 'error',
      message: err.message
    });
  }
});
```

## Framework Health Endpoints

| Framework | Default Path | Notes |
|-----------|-------------|-------|
| Express | `/health` | Common convention |
| NestJS | `/api/health` | Using @nestjs/terminus |
| Fastify | `/health` | Built-in |
| Koa | `/health` | With koa-router |
| Hono | `/health` | Built-in |
| AdonisJS | `/health` | Built-in |
| Next.js | `/api/health` | API route |
| Nuxt | `/api/health` | Server route |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Health check always fails | Check app starts: `curl localhost:3000/health` |
| Slow startup | Increase `HEALTH_CHECK_TIMEOUT` |
| Flaky checks | Increase `HEALTH_CHECK_RETRIES` |
| No health endpoint | Add `/health` route to your app |
