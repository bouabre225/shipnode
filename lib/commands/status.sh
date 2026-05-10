cmd_status() {
    load_config

    if [ "$APP_TYPE" = "backend" ]; then
        cmd_status_backend
    else
        cmd_status_frontend
    fi
}

cmd_status_backend() {
    info "Fetching status for $PM2_APP_NAME..."

    local status_data
    local node_version="${NODE_VERSION:-24}"
    [ "$node_version" = "lts" ] && node_version="24"
    status_data=$(remote_exec bash -s "$PM2_APP_NAME" "$REMOTE_PATH" "$BACKEND_PORT" "$node_version" << 'ENDSSH'
        set -e

        APP_NAME="$1"
        REMOTE_PATH="$2"
        BACKEND_PORT="$3"
        NODE_VERSION="$4"
        export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

        # Get PM2 process data as JSON
        PM2_JSON=$(mise exec "node@$NODE_VERSION" -- pm2 jlist 2>/dev/null || echo "[]")

        # Find our app in PM2 list
        APP_JSON=$(echo "$PM2_JSON" | jq ".[] | select(.name == \"$APP_NAME\")" 2>/dev/null || echo "")

        if [ -n "$APP_JSON" ]; then
            STATUS=$(echo "$APP_JSON" | jq -r '.pm2_env.status // "unknown"')
            UPTIME_SEC=$(echo "$APP_JSON" | jq -r '.pm2_env.pm_uptime // "0"')
            RESTARTS=$(echo "$APP_JSON" | jq -r '.pm2_env.restart_time // "0"')
            CPU=$(echo "$APP_JSON" | jq -r '.monit.cpu // "0"')
            MEMORY=$(echo "$APP_JSON" | jq -r '.monit.memory // "0"')
            INSTANCES=$(echo "$PM2_JSON" | jq "[.[] | select(.name == \"$APP_NAME\")] | length")

            # Format uptime
            NOW_MS=$(date +%s%3N)
            if [ "$UPTIME_SEC" != "0" ] && [ "$UPTIME_SEC" != "null" ]; then
                UPTIME_DIFF=$(( (NOW_MS - UPTIME_SEC) / 1000 ))
                UPTIME_DAYS=$((UPTIME_DIFF / 86400))
                UPTIME_HOURS=$(( (UPTIME_DIFF % 86400) / 3600 ))
                UPTIME_MINS=$(( (UPTIME_DIFF % 3600) / 60 ))
                if [ "$UPTIME_DAYS" -gt 0 ]; then
                    UPTIME="${UPTIME_DAYS}d ${UPTIME_HOURS}h ${UPTIME_MINS}m"
                elif [ "$UPTIME_HOURS" -gt 0 ]; then
                    UPTIME="${UPTIME_HOURS}h ${UPTIME_MINS}m"
                else
                    UPTIME="${UPTIME_MINS}m"
                fi
            else
                UPTIME="N/A"
            fi

            # Format memory
            if [ "$MEMORY" != "0" ] && [ "$MEMORY" != "null" ]; then
                MEMORY_MB=$((MEMORY / 1048576))
                MEMORY_STR="${MEMORY_MB}MB"
            else
                MEMORY_STR="N/A"
            fi

            echo "STATUS:$STATUS"
            echo "UPTIME:$UPTIME"
            echo "RESTARTS:$RESTARTS"
            echo "CPU:$CPU"
            echo "MEMORY:$MEMORY_STR"
            echo "INSTANCES:$INSTANCES"
        else
            echo "STATUS:stopped"
            echo "UPTIME:N/A"
            echo "RESTARTS:0"
            echo "CPU:0"
            echo "MEMORY:N/A"
            echo "INSTANCES:0"
        fi

        # Current release info
        if [ -L "$REMOTE_PATH/current" ]; then
            CURRENT_RELEASE=$(readlink "$REMOTE_PATH/current" | xargs basename 2>/dev/null || echo "unknown")
            echo "CURRENT_RELEASE:$CURRENT_RELEASE"
        else
            echo "CURRENT_RELEASE:none"
        fi

        # Previous release
        if [ -f "$REMOTE_PATH/.shipnode/releases.json" ]; then
            PREV=$(jq -r '.[-2].timestamp // "none"' "$REMOTE_PATH/.shipnode/releases.json" 2>/dev/null || echo "none")
            echo "PREV_RELEASE:$PREV"
            TOTAL=$(jq 'length' "$REMOTE_PATH/.shipnode/releases.json" 2>/dev/null || echo "0")
            echo "TOTAL_RELEASES:$TOTAL"
        else
            echo "PREV_RELEASE:none"
            echo "TOTAL_RELEASES:0"
        fi

        # Disk usage
        DISK_TOTAL=$(df -h "$REMOTE_PATH" | tail -1 | awk '{print $2}')
        DISK_USED=$(df -h "$REMOTE_PATH" | tail -1 | awk '{print $3}')
        DISK_PCT=$(df -h "$REMOTE_PATH" | tail -1 | awk '{print $5}')
        echo "DISK_TOTAL:$DISK_TOTAL"
        echo "DISK_USED:$DISK_USED"
        echo "DISK_PCT:$DISK_PCT"

        # Release directory size
        if [ -d "$REMOTE_PATH/releases" ]; then
            RELEASE_SIZE=$(du -sh "$REMOTE_PATH/releases" 2>/dev/null | cut -f1 || echo "N/A")
            RELEASE_COUNT=$(ls -1d "$REMOTE_PATH/releases"/*/ 2>/dev/null | wc -l || echo "0")
            echo "RELEASE_SIZE:$RELEASE_SIZE"
            echo "RELEASE_COUNT:$RELEASE_COUNT"
        else
            echo "RELEASE_SIZE:N/A"
            echo "RELEASE_COUNT:0"
        fi
ENDSSH
    )

    # Parse status data
    local status uptime restarts cpu memory instances
    local current_release prev_release total_releases
    local disk_total disk_used disk_pct release_size release_count

    while IFS=: read -r key value; do
        case "$key" in
            STATUS) status="$value" ;;
            UPTIME) uptime="$value" ;;
            RESTARTS) restarts="$value" ;;
            CPU) cpu="$value" ;;
            MEMORY) memory="$value" ;;
            INSTANCES) instances="$value" ;;
            CURRENT_RELEASE) current_release="$value" ;;
            PREV_RELEASE) prev_release="$value" ;;
            TOTAL_RELEASES) total_releases="$value" ;;
            DISK_TOTAL) disk_total="$value" ;;
            DISK_USED) disk_used="$value" ;;
            DISK_PCT) disk_pct="$value" ;;
            RELEASE_SIZE) release_size="$value" ;;
            RELEASE_COUNT) release_count="$value" ;;
        esac
    done <<< "$status_data"

    local status_icon
    case "$status" in
        online) status_icon="\033[0;32m● online\033[0m" ;;
        stopping|stopped) status_icon="\033[0;31m● stopped\033[0m" ;;
        errored) status_icon="\033[0;31m● errored\033[0m" ;;
        launching) status_icon="\033[1;33m● launching\033[0m" ;;
        *) status_icon="\033[0;33m● $status\033[0m" ;;
    esac

    echo ""
    echo "════════════════════════════════════════"
    echo "  Application Status"
    echo "════════════════════════════════════════"
    echo ""
    echo "  App:        $PM2_APP_NAME (backend)"
    if [ -n "${DOMAIN:-}" ]; then
        echo "  URL:        https://$DOMAIN"
    fi
    echo "  Server:     $SSH_USER@$SSH_HOST:$SSH_PORT"
    echo ""
    echo -e "  PM2:"
    echo -e "    Status:    $status_icon"
    echo "    Uptime:    ${uptime}"
    echo "    Restarts:  ${restarts}"
    echo "    Instances: ${instances:-1}"
    echo "    CPU:       ${cpu}%"
    echo "    Memory:    ${memory}"
    echo "    Port:      $BACKEND_PORT"
    echo ""
    echo "  Release:"
    echo "    Current:   ${current_release}"
    if [ "${prev_release}" != "none" ]; then
        echo "    Previous:  ${prev_release}"
    fi
    echo "    Total:     ${total_releases} releases"
    echo ""
    echo "  Disk:"
    echo "    Total:     ${disk_total}"
    echo "    Used:      ${disk_used} (${disk_pct})"
    if [ "${release_size}" != "N/A" ]; then
        echo "    Releases:  ${release_size} (${release_count} releases)"
    fi
    echo ""
    echo "════════════════════════════════════════"
    echo ""
}

cmd_status_frontend() {
    info "Fetching status..."

    local status_data
    status_data=$(remote_exec bash << 'ENDSSH'
        REMOTE_PATH="$1"

        # Current release
        if [ -L "$REMOTE_PATH/current" ]; then
            CURRENT_RELEASE=$(readlink "$REMOTE_PATH/current" | xargs basename 2>/dev/null || echo "unknown")
            CURRENT_TARGET=$(readlink "$REMOTE_PATH/current" 2>/dev/null || echo "")
            echo "CURRENT_RELEASE:$CURRENT_RELEASE"
        else
            echo "CURRENT_RELEASE:none"
        fi

        # File count and size
        if [ -d "$REMOTE_PATH/current" ] || [ -d "$REMOTE_PATH" ]; then
            SERVE_PATH="${REMOTE_PATH}/current"
            [ ! -d "$SERVE_PATH" ] && SERVE_PATH="$REMOTE_PATH"

            FILE_COUNT=$(find "$SERVE_PATH" -maxdepth 1 -type f 2>/dev/null | wc -l)
            TOTAL_SIZE=$(du -sh "$SERVE_PATH" 2>/dev/null | cut -f1 || echo "N/A")
            DIR_COUNT=$(find "$SERVE_PATH" -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l)
            LAST_MOD=$(stat -c '%y' "$SERVE_PATH" 2>/dev/null | cut -d. -f1 || echo "N/A")
            echo "FILE_COUNT:$FILE_COUNT"
            echo "TOTAL_SIZE:$TOTAL_SIZE"
            echo "DIR_COUNT:$DIR_COUNT"
            echo "LAST_MOD:$LAST_MOD"
            echo "SERVE_PATH:$SERVE_PATH"
        else
            echo "FILE_COUNT:0"
            echo "TOTAL_SIZE:N/A"
            echo "DIR_COUNT:0"
            echo "LAST_MOD:N/A"
            echo "SERVE_PATH:$REMOTE_PATH"
        fi

        # Disk usage
        DISK_TOTAL=$(df -h "$REMOTE_PATH" | tail -1 | awk '{print $2}')
        DISK_USED=$(df -h "$REMOTE_PATH" | tail -1 | awk '{print $3}')
        DISK_PCT=$(df -h "$REMOTE_PATH" | tail -1 | awk '{print $5}')
        echo "DISK_TOTAL:$DISK_TOTAL"
        echo "DISK_USED:$DISK_USED"
        echo "DISK_PCT:$DISK_PCT"

        # Caddy status
        if command -v caddy &>/dev/null; then
            CADDY_RUNNING=$(systemctl is-active caddy 2>/dev/null || echo "unknown")
            echo "CADDY_STATUS:$CADDY_RUNNING"
        else
            echo "CADDY_STATUS:not installed"
        fi
ENDSSH
    )

    local current_release file_count total_size dir_count last_mod serve_path
    local disk_total disk_used disk_pct caddy_status

    while IFS=: read -r key value; do
        case "$key" in
            CURRENT_RELEASE) current_release="$value" ;;
            FILE_COUNT) file_count="$value" ;;
            TOTAL_SIZE) total_size="$value" ;;
            DIR_COUNT) dir_count="$value" ;;
            LAST_MOD) last_mod="$value" ;;
            SERVE_PATH) serve_path="$value" ;;
            DISK_TOTAL) disk_total="$value" ;;
            DISK_USED) disk_used="$value" ;;
            DISK_PCT) disk_pct="$value" ;;
            CADDY_STATUS) caddy_status="$value" ;;
        esac
    done <<< "$status_data"

    echo ""
    echo "════════════════════════════════════════"
    echo "  Application Status"
    echo "════════════════════════════════════════"
    echo ""
    echo "  App:        $(basename "$REMOTE_PATH") (frontend)"
    if [ -n "${DOMAIN:-}" ]; then
        echo "  URL:        https://$DOMAIN"
    fi
    echo "  Server:     $SSH_USER@$SSH_HOST:$SSH_PORT"
    echo ""
    echo "  Files:"
    echo "    Serve:     ${serve_path}"
    echo "    Size:      ${total_size}"
    echo "    Files:     ${file_count}"
    echo "    Dirs:      ${dir_count}"
    echo "    Updated:   ${last_mod}"
    echo ""
    echo "  Release:"
    echo "    Current:   ${current_release}"
    echo ""
    echo "  Disk:"
    echo "    Total:     ${disk_total}"
    echo "    Used:      ${disk_used} (${disk_pct})"
    echo ""

    if [ -n "$caddy_status" ]; then
        local caddy_icon
        case "$caddy_status" in
            active) caddy_icon="\033[0;32m● active\033[0m" ;;
            inactive) caddy_icon="\033[0;31m● inactive\033[0m" ;;
            *) caddy_icon="\033[0;33m● $caddy_status\033[0m" ;;
        esac
        echo -e "  Caddy:      $caddy_icon"
    fi

    echo ""
    echo "════════════════════════════════════════"
    echo ""
}

cmd_logs() {
    load_config

    if [ "$APP_TYPE" != "backend" ]; then
        error "Logs command only available for backend apps"
    fi

    info "Streaming logs for $PM2_APP_NAME (Ctrl+C to exit)..."
    local node_version="${NODE_VERSION:-24}"
    [ "$node_version" = "lts" ] && node_version="24"
    ssh_cmd -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "export PATH=\"\$HOME/.local/bin:\$HOME/.local/share/mise/shims:\$PATH\"; mise exec node@$node_version -- pm2 logs $PM2_APP_NAME"
}

cmd_restart() {
    load_config

    if [ "$APP_TYPE" != "backend" ]; then
        error "Restart command only available for backend apps"
    fi

    info "Restarting $PM2_APP_NAME..."
    local node_version="${NODE_VERSION:-24}"
    [ "$node_version" = "lts" ] && node_version="24"
    remote_exec "export PATH=\"\$HOME/.local/bin:\$HOME/.local/share/mise/shims:\$PATH\"; mise exec node@$node_version -- pm2 restart $PM2_APP_NAME"
    success "App restarted"
}

cmd_stop() {
    load_config

    if [ "$APP_TYPE" != "backend" ]; then
        error "Stop command only available for backend apps"
    fi

    info "Stopping $PM2_APP_NAME..."
    local node_version="${NODE_VERSION:-24}"
    [ "$node_version" = "lts" ] && node_version="24"
    remote_exec "export PATH=\"\$HOME/.local/bin:\$HOME/.local/share/mise/shims:\$PATH\"; mise exec node@$node_version -- pm2 stop $PM2_APP_NAME"
    success "App stopped"
}
