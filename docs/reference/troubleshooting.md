# Troubleshooting

Common issues and solutions.

## Connection Issues

### Cannot connect to server

```bash
# Test SSH connection manually
ssh -p 22 user@your-server

# Check SSH is running on server
sudo systemctl status sshd
```

### SSH permission denied

```bash
# Check key permissions
chmod 600 ~/.ssh/id_rsa

# Verify key is added
ssh-copy-id user@your-server
```

### Host key verification failed

```bash
# Remove old host key
ssh-keygen -R your-server-ip

# Add new key
ssh-keyscan -H your-server-ip >> ~/.ssh/known_hosts
```

## Deployment Issues

### Deployment fails on sync

```bash
# Check disk space on server
ssh user@server "df -h"

# Clean old releases
ssh user@server "rm -rf /var/www/myapp/releases/*"
```

### Build fails

```bash
# Check package.json has build script
cat package.json | grep '"build"'

# Test build locally
npm run build

# Skip build on deploy
shipnode deploy --skip-build
```

### Health check fails

```bash
# Test health endpoint on server
ssh user@server "curl localhost:3000/health"

# Check app is running
ssh user@server "pm2 list"

# View logs
shipnode logs
```

### Port already in use

```bash
# Check what's using the port
ssh user@server "sudo lsof -i :3000"

# Change port in shipnode.conf
BACKEND_PORT=3001

# Or kill the process
ssh user@server "pm2 stop all"
```

### Deployment lock stuck

```bash
# Clear deployment lock
shipnode unlock

# Or manually
ssh user@server "rm -f /var/www/myapp/.shipnode/deploy.lock"
```

## PM2 Issues

### PM2 not found

```bash
# Install PM2 on server
shipnode setup

# Or manually
ssh user@server "npm install -g pm2"
```

### App keeps crashing

```bash
# Check error logs
shipnode logs

# Restart with clean state
shipnode restart

# Check memory limits
pm2 list
```

### Process not starting

```bash
# Start manually
ssh user@server "cd /var/www/myapp/current && pm2 start ecosystem.config.cjs"

# Check ecosystem config
cat /var/www/myapp/shared/ecosystem.config.cjs
```

## Caddy Issues

### HTTPS not working

```bash
# Check Caddy is running
ssh user@server "sudo systemctl status caddy"

# Check domain DNS
dig your-domain.com

# View Caddy logs
ssh user@server "sudo tail -f /var/log/caddy/"
```

### Domain shows wrong app

```bash
# Check Caddy config
ssh user@server "cat /var/www/myapp/shared/Caddyfile"

# Reload Caddy
ssh user@server "sudo caddy reload"
```

## Template Issues

### Ejected templates not used

```bash
# Verify template exists
ls -la .shipnode/templates/

# Check template resolution
shipnode config

# Reset to defaults
rm .shipnode/templates/ecosystem.config.cjs
rm .shipnode/templates/Caddyfile.caddy
```

## General Debugging

```bash
# Run with debug output
shipnode deploy --debug

# Check shipnode.conf
shipnode config

# Validate config
shipnode config validate

# Run doctor
shipnode doctor
```

## Getting Help

1. Check this troubleshooting guide
2. Run `shipnode doctor`
3. Check `shipnode logs`
4. Search [issues](https://github.com/devalade/shipnode/issues)
5. Open a new issue with logs
