# Troubleshooting

## Fast Triage

Ask for or inspect:

```bash
shipnode config validate
shipnode doctor
shipnode logs
cat shipnode.conf
cat package.json
```

Use `--debug` when the failing command hides useful detail:

```bash
shipnode deploy --debug
```

## SSH Connection Fails

Verify manually:

```bash
ssh -p 22 user@your-server
```

Common fixes:

```bash
chmod 600 ~/.ssh/id_rsa
ssh-copy-id user@your-server
ssh-keygen -R your-server-ip
ssh-keyscan -H your-server-ip >> ~/.ssh/known_hosts
```

If the SSH port changed during hardening, update both firewall rules and `SSH_PORT`.

## Sync or Deploy Fails

Check server disk and remote path permissions:

```bash
ssh user@server "df -h"
ssh user@server "ls -ld /var/www /var/www/myapp"
```

Avoid deleting all releases unless necessary. If disk pressure is the issue, prefer reducing old releases while keeping at least one rollback target.

## Build Fails

Check local scripts and package manager:

```bash
cat package.json
npm run build
```

For frontends with pre-built assets:

```bash
shipnode deploy --skip-build
```

For package-manager mismatch, set:

```bash
PKG_MANAGER=npm
```

or `yarn`, `pnpm`, `bun`.

## Health Check Fails

Health checks call `localhost:$BACKEND_PORT$HEALTH_CHECK_PATH` on the server.

Verify:

```bash
ssh user@server "curl -i localhost:3000/health"
shipnode logs
ssh user@server "pm2 list"
```

Common causes:

- App has no `/health` endpoint.
- `BACKEND_PORT` does not match the app's actual port.
- App binds only to the wrong host or exits after start.
- Environment variables are missing.
- Build output or start command is wrong.

Prefer fixing the mismatch over disabling health checks. Disable only as a temporary emergency measure:

```bash
HEALTH_CHECK_ENABLED=false
```

## Port Already In Use

Find the process:

```bash
ssh user@server "sudo lsof -i :3000"
```

Then either change `BACKEND_PORT`, stop the conflicting process, or adjust PM2 app naming so ShipNode reloads the intended process.

## Deployment Lock Stuck

Use ShipNode first:

```bash
shipnode unlock
```

Manual cleanup should match the actual remote path:

```bash
ssh user@server "rm -f /var/www/myapp/.deploy.lock"
```

## PM2 Issues

If PM2 is missing:

```bash
shipnode setup
```

If the app crashes:

```bash
shipnode logs
shipnode restart
ssh user@server "pm2 list"
```

## Caddy or HTTPS Issues

Check DNS and service state:

```bash
dig example.com
ssh user@server "sudo systemctl status caddy"
ssh user@server "sudo caddy validate --config /etc/caddy/Caddyfile"
```

Ports 80 and 443 must be reachable from the internet for automatic HTTPS.

## Environment Variable Issues

ShipNode does not sync `.env` automatically.

Upload:

```bash
shipnode env
shipnode restart
```

Verify on the server:

```bash
ssh user@server "ls -la /var/www/myapp/shared/.env"
```
