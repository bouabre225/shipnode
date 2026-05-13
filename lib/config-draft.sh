suggest_config_app_name() {
    local app_name=""

    if [ -f "package.json" ] && command -v jq &> /dev/null; then
        app_name=$(jq -r '.name // empty' package.json 2>/dev/null \
            | sed -E 's/^@[^/]+\///' \
            | tr ' ' '-' \
            | sed -E 's/[^A-Za-z0-9._-]+/-/g' \
            | sed -E 's/-+/-/g' \
            | sed -E 's/^-+|-+$//g')
    fi

    if [ -z "$app_name" ]; then
        app_name=$(basename "$PWD")
    fi

    echo "$app_name"
}

emit_config_draft() {
    local generated_by="$1"
    local health_path_value="${health_check_path:-${health_path:-/health}}"

    echo ""
    echo "# ShipNode Configuration"
    echo "# $generated_by"
    echo ""
    echo "# Application type"
    echo "APP_TYPE=$app_type"
    echo ""
    echo "# SSH Connection"
    echo "SSH_USER=$ssh_user"
    echo "SSH_HOST=$ssh_host"
    echo "SSH_PORT=$ssh_port"
    echo ""
    echo "# Node.js version (lts, 18, 20, 22, etc.)"
    echo "NODE_VERSION=lts"
    echo ""
    echo "# Deployment path"
    echo "REMOTE_PATH=$remote_path"

    if [ "$app_type" = "backend" ]; then
        echo ""
        echo "# Backend settings"
        echo "PM2_APP_NAME=$pm2_app_name"
        echo "BACKEND_PORT=$backend_port"
    fi

    if [ -n "$domain" ]; then
        echo ""
        echo "# Domain"
        echo "DOMAIN=$domain"
    fi

    echo ""
    echo "# Environment file"
    echo "# ENV_FILE=.env"

    echo ""
    echo "# Zero-downtime deployment"
    echo "ZERO_DOWNTIME=$zero_downtime"
    echo "KEEP_RELEASES=$keep_releases"

    if [ "$app_type" = "backend" ] && [ "$health_enabled" = "true" ]; then
        echo ""
        echo "# Health checks"
        echo "HEALTH_CHECK_ENABLED=$health_enabled"
        echo "HEALTH_CHECK_PATH=$health_path_value"
        echo "HEALTH_CHECK_TIMEOUT=$health_timeout"
        echo "HEALTH_CHECK_RETRIES=$health_retries"
    fi

    emit_database_config
}
