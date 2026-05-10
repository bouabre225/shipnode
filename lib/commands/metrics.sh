cmd_metrics() {
    load_config

    if [ "$APP_TYPE" != "backend" ]; then
        error "Metrics command only available for backend apps (uses PM2)"
    fi

    info "Opening PM2 monitoring dashboard for $PM2_APP_NAME..."
    info "Press Ctrl+C to exit"
    echo ""
    local node_version="${NODE_VERSION:-24}"
    [ "$node_version" = "lts" ] && node_version="24"
    ssh_cmd -t -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "export PATH=\"\$HOME/.local/bin:\$HOME/.local/share/mise/shims:\$PATH\"; mise exec node@$node_version -- pm2 monit"
}
