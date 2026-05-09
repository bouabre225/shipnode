cmd_config() {
    local subcmd="${1:-show}"

    case "$subcmd" in
        show)
            cmd_config_show
            ;;
        validate)
            cmd_config_validate
            ;;
        path)
            echo "$SHIPNODE_CONFIG_FILE"
            ;;
        *)
            error "Unknown config command: '$subcmd'\nAvailable: show, validate, path"
            ;;
    esac
}

cmd_config_show() {
    if [ ! -f "$SHIPNODE_CONFIG_FILE" ]; then
        error "$SHIPNODE_CONFIG_FILE not found. Run 'shipnode init' first."
    fi

    load_config

    echo ""
    echo "═══════════════════════════════════════"
    echo "  ShipNode Configuration"
    echo "═══════════════════════════════════════"
    echo ""
    echo "  Config file:  $SHIPNODE_CONFIG_FILE"
    echo ""
    echo "  App Type:     $APP_TYPE"
    echo "  SSH:          $SSH_USER@$SSH_HOST:$SSH_PORT"
    echo "  Remote Path:  $REMOTE_PATH"

    if [ "$APP_TYPE" = "backend" ]; then
        echo ""
        echo "  PM2 Name:     $PM2_APP_NAME"
        echo "  Backend Port: $BACKEND_PORT"
    fi

    if [ -n "$DOMAIN" ]; then
        echo "  Domain:       $DOMAIN"
    fi

    echo ""
    echo "  Zero Downtime:  ${ZERO_DOWNTIME}"
    echo "  Keep Releases:  ${KEEP_RELEASES}"

    if [ "$APP_TYPE" = "backend" ]; then
        echo ""
        echo "  Health Check:"
        echo "    Enabled:    ${HEALTH_CHECK_ENABLED}"
        echo "    Path:       ${HEALTH_CHECK_PATH}"
        echo "    Timeout:    ${HEALTH_CHECK_TIMEOUT}s"
        echo "    Retries:    ${HEALTH_CHECK_RETRIES}"
    fi

    echo ""

    echo "  Database Backups:"
    echo "    Enabled:    ${DB_BACKUP_ENABLED:-false}"
    if [ "${DB_BACKUP_ENABLED:-false}" = "true" ]; then
        echo "    Bucket:     ${DB_BACKUP_S3_BUCKET:-}"
        echo "    Prefix:     ${DB_BACKUP_S3_PREFIX:-${PM2_APP_NAME:-$(basename "$REMOTE_PATH")}}"
        echo "    Schedule:   ${DB_BACKUP_SCHEDULE:-daily}"
        echo "    Retention:  ${DB_BACKUP_RETENTION_DAYS:-14} days (local)"
    fi

    echo ""

    if [ -f ".shipnode/templates/ecosystem.config.cjs" ]; then
        echo "  Templates:"
        echo "    PM2:       .shipnode/templates/ecosystem.config.cjs (custom)"
    fi
    if [ -f ".shipnode/templates/Caddyfile.caddy" ]; then
        echo "    Caddy:     .shipnode/templates/Caddyfile.caddy (custom)"
    fi

    echo "═══════════════════════════════════════"
    echo ""
}

cmd_config_validate() {
    if [ ! -f "$SHIPNODE_CONFIG_FILE" ]; then
        error "$SHIPNODE_CONFIG_FILE not found"
    fi

    info "Validating $SHIPNODE_CONFIG_FILE..."

    local errors=0

    if ! grep -q "^APP_TYPE=" "$SHIPNODE_CONFIG_FILE" 2>/dev/null; then
        warn "  Missing: APP_TYPE (required)"
        errors=$((errors + 1))
    else
        local app_type=$(grep "^APP_TYPE=" "$SHIPNODE_CONFIG_FILE" | cut -d= -f2)
        if [ "$app_type" != "backend" ] && [ "$app_type" != "frontend" ]; then
            warn "  Invalid: APP_TYPE must be 'backend' or 'frontend' (got: '$app_type')"
            errors=$((errors + 1))
        else
            success "  APP_TYPE=$app_type"
        fi
    fi

    local required_vars="SSH_USER SSH_HOST REMOTE_PATH"
    for var in $required_vars; do
        if ! grep -q "^${var}=" "$SHIPNODE_CONFIG_FILE" 2>/dev/null; then
            warn "  Missing: $var (required)"
            errors=$((errors + 1))
        else
            local val=$(grep "^${var}=" "$SHIPNODE_CONFIG_FILE" | cut -d= -f2)
            if [ -z "$val" ]; then
                warn "  Empty: $var"
                errors=$((errors + 1))
            else
                success "  $var=$val"
            fi
        fi
    done

    local app_type=$(grep "^APP_TYPE=" "$SHIPNODE_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    if [ "$app_type" = "backend" ]; then
        for var in PM2_APP_NAME BACKEND_PORT; do
            if ! grep -q "^${var}=" "$SHIPNODE_CONFIG_FILE" 2>/dev/null; then
                warn "  Missing: $var (required for backend)"
                errors=$((errors + 1))
            else
                local val=$(grep "^${var}=" "$SHIPNODE_CONFIG_FILE" | cut -d= -f2)
                if [ -z "$val" ]; then
                    warn "  Empty: $var"
                    errors=$((errors + 1))
                else
                    success "  $var=$val"
                fi
            fi
        done
    fi

    if grep -q "^DB_BACKUP_ENABLED=true" "$SHIPNODE_CONFIG_FILE" 2>/dev/null; then
        if ! grep -q "^DB_BACKUP_S3_BUCKET=" "$SHIPNODE_CONFIG_FILE" 2>/dev/null; then
            warn "  Missing: DB_BACKUP_S3_BUCKET (required when DB_BACKUP_ENABLED=true)"
            errors=$((errors + 1))
        else
            local bucket=$(grep "^DB_BACKUP_S3_BUCKET=" "$SHIPNODE_CONFIG_FILE" | cut -d= -f2)
            if [ -z "$bucket" ]; then
                warn "  Empty: DB_BACKUP_S3_BUCKET"
                errors=$((errors + 1))
            else
                success "  DB_BACKUP_S3_BUCKET=$bucket"
            fi
        fi
    fi

    echo ""
    if [ $errors -eq 0 ]; then
        success "Configuration is valid!"
    else
        error "Configuration has $errors error(s)"
    fi
}
