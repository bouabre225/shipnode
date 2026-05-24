render_caddy_backend_config() {
    local template_file
    template_file=$(resolve_template "Caddyfile.caddy")

    if [ -n "$template_file" ]; then
        info "Using custom Caddy template: $template_file"
        render_template "$template_file" \
            DOMAIN "$DOMAIN" \
            APP_NAME "$PM2_APP_NAME" \
            BACKEND_PORT "$BACKEND_PORT"
        return
    fi

    cat << CADDY_EOF
$DOMAIN {
    reverse_proxy localhost:$BACKEND_PORT
    encode gzip

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
    }

    log {
        output file /var/log/caddy/$PM2_APP_NAME.log
        format json
    }
}
CADDY_EOF
}

render_caddy_frontend_config() {
    local app_name="$1"
    local serve_path="$2"
    local template_file
    template_file=$(resolve_template "Caddyfile.caddy")

    if [ -n "$template_file" ]; then
        info "Using custom Caddy template: $template_file"
        render_template "$template_file" \
            DOMAIN "$DOMAIN" \
            APP_NAME "$app_name" \
            SERVE_PATH "$serve_path"
        return
    fi

    cat << CADDY_EOF
$DOMAIN {
    root * $serve_path
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
        output file /var/log/caddy/$app_name.log
        format json
    }
}
CADDY_EOF
}

install_caddy_app_config() {
    local app_name="$1"
    local caddy_config="$2"

    remote_exec bash << ENDSSH
        set -e

        mkdir -p /etc/caddy/conf.d

        if [ ! -f /etc/caddy/Caddyfile ]; then
            cat > /etc/caddy/Caddyfile << 'MAIN_EOF'
# ShipNode managed Caddyfile
# Per-app configurations are in /etc/caddy/conf.d/

import /etc/caddy/conf.d/*.caddy
MAIN_EOF
        elif ! grep -q "import /etc/caddy/conf.d/\*.caddy" /etc/caddy/Caddyfile 2>/dev/null; then
            cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup
            echo "" >> /etc/caddy/Caddyfile
            echo "import /etc/caddy/conf.d/*.caddy" >> /etc/caddy/Caddyfile
        fi

        cat > /etc/caddy/conf.d/$app_name.caddy << 'APP_EOF'
$caddy_config
APP_EOF

        caddy reload --config /etc/caddy/Caddyfile
ENDSSH
}
