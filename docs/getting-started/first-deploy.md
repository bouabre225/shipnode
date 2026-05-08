# First Deploy

A complete tutorial for deploying your first application with ShipNode.

## Goal

By the end of this tutorial, you'll have a Node.js Express API running on your server with:
- Zero-downtime deployments
- Automatic HTTPS
- Health check monitoring
- Rollback capability

## Prerequisites

- A server with SSH access (Ubuntu/Debian)
- A domain name (optional, but recommended)
- DNS configured to point to your server's IP

## Step 1: Prepare Your Server

Make sure your server has:
- SSH access (password or key)
- Port 22 open (default SSH)
- Ports 80 and 443 open (for HTTP/HTTPS)

## Step 2: Create a Simple Express API

If you don't have an existing project, create one:

```bash
mkdir myapi && cd myapi
npm init -y
npm install express
```

Create `index.js`:

```javascript
const express = require('express');
const app = express();

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/', (req, res) => {
  res.json({ message: 'Hello from ShipNode!' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

Update `package.json`:

```json
{
  "name": "myapi",
  "scripts": {
    "start": "node index.js"
  }
}
```

## Step 3: Initialize ShipNode

```bash
shipnode init
```

Fill in the prompts:

```
Application type: backend
SSH user: your-username
SSH host: your-server-ip
SSH port: 22
Remote path: /var/www/myapi
PM2 name: myapi
Backend port: 3000
Domain: api.yourdomain.com  (optional)
```

This creates `shipnode.conf` in your project.

## Step 4: Setup Your Server

```bash
shipnode setup
```

Wait for the setup to complete. This installs:
- Node.js 20 LTS
- PM2
- Caddy

## Step 5: Deploy

```bash
shipnode deploy
```

You'll see output like:

```
[+] Syncing files to server...
[+] Installing dependencies...
[+] Building...
[+] Switching to new release...
[+] Running health check...
[+] Deployment successful!
```

## Step 6: Verify

Check your deployment:

```bash
shipnode status
```

Visit `https://api.yourdomain.com` (or `http://your-server-ip`).

## Step 7: Make a Change

Edit your code, then deploy again:

```bash
shipnode deploy
```

ShipNode will:
1. Create a new timestamped release
2. Switch the `current` symlink atomically
3. Run a health check
4. Keep the old release for rollback

## Step 8: Rollback (If Needed)

If something goes wrong:

```bash
shipnode rollback
```

ShipNode switches back to the previous release instantly.

## Next Steps

- [Add a Database](../guides/configuration/shipnode-conf.md) - Configure PostgreSQL, MySQL, SQLite, or Redis
- [Custom Templates](../guides/configuration/custom-templates.md) - Customize PM2/Caddy
- [Health Checks](../guides/health-checks.md) - Configure health endpoints
- [CI/CD](../guides/ci-cd.md) - Automate deployments with GitHub Actions
