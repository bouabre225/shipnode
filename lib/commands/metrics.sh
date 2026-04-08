cmd_metrics() {
    load_config

    if [ "$APP_TYPE" != "backend" ]; then
        error "Metrics command only available for backend apps (uses PM2)"
    fi

    info "Opening PM2 monitoring dashboard for $PM2_APP_NAME..."
    info "Press Ctrl+C to exit"
    echo ""
    ssh_cmd -t -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "pm2 monit"
}
