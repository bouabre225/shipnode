# Custom Templates

Customize PM2 and Caddy configuration for your needs.

## Eject Templates

```bash
shipnode eject            # eject PM2 + Caddy templates
shipnode eject pm2        # eject only PM2
shipnode eject caddy      # eject only Caddy
```

This copies templates to `.shipnode/templates/`:

```
.shipnode/templates/
├── ecosystem.config.cjs   # PM2 config
└── Caddyfile.caddy       # Caddy config
```

Ejected templates are **preserved across deploys**.

## Template Variables

Templates use `{{VAR}}` placeholders:

| Variable | Description |
|----------|-------------|
| `{{APP_NAME}}` | PM2 process name |
| `{{INTERPRETER}}` | Package manager (npm, yarn, pnpm, bun) |
| `{{REMOTE_PATH}}` | Deployment path |
| `{{BACKEND_PORT}}` | Application port |
| `{{DOMAIN}}` | Domain name |
| `{{SERVE_PATH}}` | Static files path (frontend) |

## Custom PM2 Config

Edit `.shipnode/templates/ecosystem.config.cjs`:

```javascript
module.exports = {
  apps: [{
    name: "{{APP_NAME}}",
    script: "{{INTERPRETER}}",
    args: "start",
    cwd: "{{REMOTE_PATH}}/current",
    instances: "max",              // use all CPU cores
    exec_mode: "cluster",          // enable cluster mode
    max_memory_restart: "1G",       // restart if > 1GB memory
    env: {
      NODE_ENV: "production",
      PORT: {{BACKEND_PORT}}
    },
    error_file: "{{REMOTE_PATH}}/logs/pm2-error.log",
    out_file: "{{REMOTE_PATH}}/logs/pm2-out.log",
  }]
};
```

## Custom Caddy Config

Edit `.shipnode/templates/Caddyfile.caddy`:

```
{{DOMAIN}} {
    reverse_proxy localhost:{{BACKEND_PORT}}
    encode gzip

    # Rate limiting
    rate_limit {
        zone dynamic_zone {
            key {remote_host}
            events 100
            window 1s
        }
    }

    # Security headers
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        Content-Security-Policy "default-src 'self'"
    }

    # Logging
    log {
        output file /var/log/caddy/{{APP_NAME}}.log
        format json
    }
}
```

## Frontend Caddy Template

For frontends, `{{SERVE_PATH}}` points to the static files:

```
{{DOMAIN}} {
    root {{REMOTE_PATH}}/current/{{SERVE_PATH}}
    encode gzip

    # SPA routing
    try_files {path} /index.html

    # Cache static assets
    @static {
        file
        path *.css *.js *.png *.jpg *.svg *.ico
    }
    header @static Cache-Control "max-age=31536000, immutable"
}
```

## Reset to Defaults

Remove ejected templates:

```bash
rm .shipnode/templates/ecosystem.config.cjs
rm .shipnode/templates/Caddyfile.caddy
```

ShipNode will use built-in defaults.

## Template Resolution Order

1. `.shipnode/templates/ecosystem.config.cjs` (ejected)
2. `ecosystem.config.cjs` in project root (user-provided)
3. Built-in defaults
