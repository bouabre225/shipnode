EJECT_DIR=".shipnode/templates"

cmd_eject() {
    local target="${1:-all}"

    if [ "$target" != "pm2" ] && [ "$target" != "caddy" ] && [ "$target" != "all" ]; then
        error "Unknown eject target: '$target'\nAvailable: pm2, caddy, all"
    fi

    local config_loaded=false
    if [ -f "$SHIPNODE_CONFIG_FILE" ]; then
        load_config
        config_loaded=true
    fi

    info "Ejecting $target configuration templates..."

    mkdir -p "$EJECT_DIR"

    local ejected=0

    if [ "$target" = "pm2" ] || [ "$target" = "all" ]; then
        eject_pm2
        ejected=$((ejected + 1))
    fi

    if [ "$target" = "caddy" ] || [ "$target" = "all" ]; then
        eject_caddy
        ejected=$((ejected + 1))
    fi

    echo ""
    if [ $ejected -gt 0 ]; then
        success "Templates ejected to $EJECT_DIR/"
        echo ""
        info "Ejected files are preserved across deploys. Edit them to customize:"
        echo "  - PM2: cluster mode, memory limits, env vars, cron restarts"
        echo "  - Caddy: TLS options, headers, rate limiting, caching"
        echo ""
        info "To reset to defaults, delete the files in $EJECT_DIR/"
    fi
}

eject_pm2() {
    local target="$EJECT_DIR/ecosystem.config.cjs"

    if [ -f "$target" ]; then
        warn "$target already exists (skipping)"
        warn "  Delete it first to reset: rm $target"
        return
    fi

    local template_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/templates"

    if [ -f "$template_dir/ecosystem.config.cjs.tmpl" ]; then
        cp "$template_dir/ecosystem.config.cjs.tmpl" "$target"
    else
        cat > "$target" << 'TEMPLATE'
// ShipNode PM2 Ecosystem Configuration
// Customize this file - it will be preserved across deploys
//
// Available variables (auto-replaced on deploy):
//   {{APP_NAME}}, {{INTERPRETER}}, {{REMOTE_PATH}}, {{BACKEND_PORT}}
//
// Docs: https://pm2.keymetrics.io/docs/usage/application-declaration/

module.exports = {
  apps: [{
    name: "{{APP_NAME}}",
    script: "{{INTERPRETER}}",
    args: "start",
    cwd: "{{REMOTE_PATH}}/current",
    autorestart: true,
    max_restarts: 10,
    min_uptime: '10s',

    // Uncomment for cluster mode:
    // instances: "max",
    // exec_mode: "cluster",

    // Uncomment to limit memory:
    // max_memory_restart: "1G",

    env: {
      NODE_ENV: "production",
      PORT: {{BACKEND_PORT}}
    }
  }]
};
TEMPLATE
    fi

    success "Ejected PM2 template → $target"
}

eject_caddy() {
    local app_type="${APP_TYPE:-backend}"

    if [ "$app_type" = "backend" ]; then
        eject_caddy_backend
    else
        eject_caddy_frontend
    fi
}

eject_caddy_backend() {
    local target="$EJECT_DIR/Caddyfile.caddy"

    if [ -f "$target" ]; then
        warn "$target already exists (skipping)"
        warn "  Delete it first to reset: rm $target"
        return
    fi

    local template_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/templates"

    if [ -f "$template_dir/Caddyfile.backend.tmpl" ]; then
        cp "$template_dir/Caddyfile.backend.tmpl" "$target"
    else
        cat > "$target" << 'TEMPLATE'
# ShipNode Caddy Configuration (Backend)
# Available variables: {{DOMAIN}}, {{APP_NAME}}, {{BACKEND_PORT}}

{{DOMAIN}} {
    reverse_proxy localhost:{{BACKEND_PORT}}
    encode gzip

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
    }

    log {
        output file /var/log/caddy/{{APP_NAME}}.log
        format json
    }
}
TEMPLATE
    fi

    success "Ejected Caddy (backend) template → $target"
}

eject_caddy_frontend() {
    local target="$EJECT_DIR/Caddyfile.caddy"

    if [ -f "$target" ]; then
        warn "$target already exists (skipping)"
        warn "  Delete it first to reset: rm $target"
        return
    fi

    local template_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/templates"

    if [ -f "$template_dir/Caddyfile.frontend.tmpl" ]; then
        cp "$template_dir/Caddyfile.frontend.tmpl" "$target"
    else
        cat > "$target" << 'TEMPLATE'
# ShipNode Caddy Configuration (Frontend)
# Available variables: {{DOMAIN}}, {{APP_NAME}}, {{SERVE_PATH}}

{{DOMAIN}} {
    root * {{SERVE_PATH}}
    file_server
    encode gzip

    try_files {path} /index.html

    @static {
        path *.css *.js *.png *.jpg *.jpeg *.gif *.svg *.ico *.woff *.woff2
    }
    header @static Cache-Control "public, max-age=31536000, immutable"

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
        Referrer-Policy strict-origin-when-cross-origin
    }

    log {
        output file /var/log/caddy/{{APP_NAME}}.log
        format json
    }
}
TEMPLATE
    fi

    success "Ejected Caddy (frontend) template → $target"
}
