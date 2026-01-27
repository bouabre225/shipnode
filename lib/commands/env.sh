cmd_env() {
    load_config

    # Check if .env file exists locally
    if [ ! -f .env ]; then
        error ".env file not found in current directory"
    fi

    info "Uploading .env file to server..."

    # Determine target path based on deployment mode
    if [ "$ZERO_DOWNTIME" = "true" ]; then
        # Upload to shared directory for zero-downtime deployments
        TARGET_PATH="$REMOTE_PATH/shared/.env"
        ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "mkdir -p $REMOTE_PATH/shared"
    else
        # Upload directly to app directory for legacy deployments
        TARGET_PATH="$REMOTE_PATH/.env"
        ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "mkdir -p $REMOTE_PATH"
    fi

    # Upload the .env file
    scp -P "$SSH_PORT" .env "$SSH_USER@$SSH_HOST:$TARGET_PATH"

    success ".env file uploaded to $TARGET_PATH"

    # Restart backend app if running to reload env vars
    if [ "$APP_TYPE" = "backend" ]; then
        info "Restarting app to reload environment variables..."
        if ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "pm2 describe $PM2_APP_NAME" &> /dev/null; then
            ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "pm2 reload $PM2_APP_NAME"
            success "App restarted with new environment variables"
        else
            warn "App not running. Environment variables will be loaded on next deploy."
        fi
    fi
}

# Show help
