generate_release_timestamp() {
    date +"%Y%m%d%H%M%S"
}

current_time_ms() {
    local value
    value=$(date +%s%3N 2>/dev/null || true)
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
    else
        echo $(( $(date +%s) * 1000 ))
    fi
}

get_release_path() {
    local timestamp=$1
    echo "$REMOTE_PATH/releases/$timestamp"
}

setup_release_structure() {
    remote_exec bash << ENDSSH
        mkdir -p $REMOTE_PATH/{releases,shared,.shipnode}
        if [ ! -f $REMOTE_PATH/.shipnode/releases.json ]; then
            echo "[]" > $REMOTE_PATH/.shipnode/releases.json
        fi
ENDSSH
}

validate_shared_resource_paths() {
    local resource

    for resource in $SHARED_DIRS $SHARED_FILES; do
        case "$resource" in
            ""|"."|/*|*..*|*~*|*//*|shared|shared/*|releases|releases/*|current|current/*|.shipnode|.shipnode/*)
                error "Invalid shared resource path: '$resource'. Use relative app paths outside ShipNode-managed directories."
                ;;
        esac
    done
}

link_shared_resources() {
    local release_path="$1"
    local shared_root="${2:-$REMOTE_PATH/shared}"

    if [ -z "$SHARED_DIRS" ] && [ -z "$SHARED_FILES" ]; then
        return 0
    fi

    validate_shared_resource_paths
    info "Linking shared resources..."

    remote_exec bash -s "$release_path" "$shared_root" "$SHARED_DIRS" "$SHARED_FILES" << 'ENDSSH'
        set -e

        release_path="$1"
        shared_root="$2"
        shared_dirs="$3"
        shared_files="$4"

        promote_or_link_dir() {
            resource="$1"
            release_resource="$release_path/$resource"
            shared_resource="$shared_root/$resource"
            shared_parent="$(dirname "$shared_resource")"
            release_parent="$(dirname "$release_resource")"

            mkdir -p "$shared_parent" "$release_parent"

            if [ ! -e "$shared_resource" ] && [ -d "$release_resource" ] && [ ! -L "$release_resource" ]; then
                mv "$release_resource" "$shared_resource"
            else
                mkdir -p "$shared_resource"
                if [ -e "$release_resource" ] || [ -L "$release_resource" ]; then
                    rm -rf "$release_resource"
                fi
            fi

            ln -sfn "$shared_resource" "$release_resource"
        }

        promote_or_link_file() {
            resource="$1"
            release_resource="$release_path/$resource"
            shared_resource="$shared_root/$resource"
            shared_parent="$(dirname "$shared_resource")"
            release_parent="$(dirname "$release_resource")"

            mkdir -p "$shared_parent" "$release_parent"

            if [ ! -e "$shared_resource" ] && [ -f "$release_resource" ] && [ ! -L "$release_resource" ]; then
                mv "$release_resource" "$shared_resource"
            fi

            if [ -e "$shared_resource" ]; then
                if [ -e "$release_resource" ] || [ -L "$release_resource" ]; then
                    rm -rf "$release_resource"
                fi
                ln -sfn "$shared_resource" "$release_resource"
            fi
        }

        for resource in $shared_dirs; do
            [ -n "$resource" ] && promote_or_link_dir "$resource"
        done

        for resource in $shared_files; do
            [ -n "$resource" ] && promote_or_link_file "$resource"
        done
ENDSSH

    success "Shared resources linked"
}

acquire_deploy_lock() {
    local result
    result=$(remote_exec bash -s "$REMOTE_PATH" << 'ENDSSH'
        REMOTE_PATH="$1"
        mkdir -p "$REMOTE_PATH/.shipnode"
        LOCK_FILE="$REMOTE_PATH/.shipnode/deploy.lock"

        # Check for stale lock (older than 30 minutes)
        if [ -f "$LOCK_FILE" ]; then
            LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
            if [ "$LOCK_AGE" -gt 1800 ]; then
                echo "Removing stale lock file (${LOCK_AGE}s old)"
                rm -f "$LOCK_FILE"
            else
                echo "ERROR: Deployment in progress (lock age: ${LOCK_AGE}s)"
                exit 1
            fi
        fi

        # Create lock with timestamp
        date +%s > "$LOCK_FILE"
        echo "Lock acquired"
ENDSSH
    )
    echo "$result"
    if [[ "$result" == *"ERROR"* ]]; then
        error "Failed to acquire deployment lock"
    fi
}

release_deploy_lock() {
    remote_exec "rm -f $REMOTE_PATH/.shipnode/deploy.lock" || true
}

switch_symlink() {
    local release_path=$1
    remote_exec bash << ENDSSH
        cd $REMOTE_PATH
        ln -sfn $release_path current.tmp
        mv -Tf current.tmp current
ENDSSH
}

perform_health_check() {
    local max_retries=${HEALTH_CHECK_RETRIES:-3}
    local timeout=${HEALTH_CHECK_TIMEOUT:-30}
    local path=${HEALTH_CHECK_PATH:-/health}
    local port=${BACKEND_PORT:-3000}

    info "Running health check (${max_retries} retries, ${timeout}s timeout)..."

    _HEALTH_CHECK_ATTEMPTS=0
    _HEALTH_CHECK_RESPONSE_MS=""

    for i in $(seq 1 $max_retries); do
        _HEALTH_CHECK_ATTEMPTS=$i

        local start_ms
        start_ms=$(current_time_ms)

        if remote_exec "timeout $timeout curl -sf http://localhost:$port$path" > /dev/null 2>&1; then
            local end_ms
            end_ms=$(current_time_ms)
            if [ "$start_ms" != "0" ] && [ "$end_ms" != "0" ]; then
                _HEALTH_CHECK_RESPONSE_MS=$(( end_ms - start_ms ))
            fi
            success "Health check passed (attempt $i)"
            return 0
        fi
        [ $i -lt $max_retries ] && warn "Health check attempt $i failed, retrying..."
        sleep 2
    done

    error "Health check failed after $max_retries attempts"
    return 1
}

record_release() {
    local timestamp=$1
    local status=$2
    local duration="${3:-}"
    local commit="${4:-}"
    local health_attempts="${5:-}"
    local health_response_ms="${6:-}"
    local previous="${7:-}"

    local extra_fields=""
    if [ -n "$duration" ]; then
        extra_fields="$extra_fields, \"duration_seconds\": $duration"
    fi
    if [ -n "$commit" ] && [ "$commit" != "" ]; then
        extra_fields="$extra_fields, \"commit\": \"$commit\""
    fi
    if [ -n "$health_attempts" ]; then
        extra_fields="$extra_fields, \"health_check\": {\"passed\": true, \"attempts\": $health_attempts"
        if [ -n "$health_response_ms" ]; then
            extra_fields="$extra_fields, \"response_time_ms\": $health_response_ms"
        fi
        extra_fields="$extra_fields }"
    fi
    if [ -n "$previous" ]; then
        extra_fields="$extra_fields, \"previous_release\": \"$previous\""
    fi

    remote_exec bash << ENDSSH
        cd $REMOTE_PATH/.shipnode
        CURRENT_DATE=\$(date -Is)
        jq ". + [{\"timestamp\":\"$timestamp\",\"date\":\"\$CURRENT_DATE\",\"status\":\"$status\"$extra_fields}]" releases.json > releases.json.tmp
        mv releases.json.tmp releases.json
ENDSSH
}

get_previous_release() {
    remote_exec bash << ENDSSH
        cd $REMOTE_PATH/.shipnode
        cat releases.json | jq -r '.[-2].timestamp // empty'
ENDSSH
}

cleanup_old_releases() {
    local keep=${KEEP_RELEASES:-5}
    remote_exec bash << ENDSSH
        cd $REMOTE_PATH/releases
        ls -t | tail -n +$((keep + 1)) | xargs -r rm -rf
ENDSSH
    info "Cleaned up old releases (keeping last $keep)"
}

rollback_to_release() {
    local timestamp=$1
    local release_path="$REMOTE_PATH/releases/$timestamp"

    info "Rolling back to release $timestamp..."
    switch_symlink "$release_path"

    if [ "$APP_TYPE" = "backend" ]; then
        local node_version="${NODE_VERSION:-24}"
        [ "$node_version" = "lts" ] && node_version="24"
        remote_exec bash << ENDSSH
            set -e
            export PATH="\$HOME/.local/bin:\$HOME/.local/share/mise/shims:\$PATH"
            cd $REMOTE_PATH/current
            mise exec node@$node_version -- pm2 startOrReload $REMOTE_PATH/shared/ecosystem.config.cjs --update-env
            mise exec node@$node_version -- pm2 save
ENDSSH
    fi

    success "Rolled back to $timestamp"
}

# Run pre-deploy hook on remote server
# Returns: 0 on success, 1 on failure
run_pre_deploy_hook() {
    local release_path=$1
    local hook_script=${PRE_DEPLOY_SCRIPT:-".shipnode/pre-deploy.sh"}

    # Check if hook script exists locally
    if [ ! -f "$hook_script" ]; then
        return 0
    fi

    info "Running pre-deploy hook: $hook_script"

    # Copy hook script to release directory
    if ! remote_copy "$hook_script" "$SSH_USER@$SSH_HOST:$release_path/.shipnode-pre-deploy.sh" 2>&1; then
        error "Failed to copy pre-deploy hook to server"
        return 1
    fi

    # Execute hook on remote server with output streaming (not captured)
    remote_exec bash << ENDSSH
        set -e
        cd $release_path

        # Export environment variables for hook
        export RELEASE_PATH="$release_path"
        export REMOTE_PATH="$REMOTE_PATH"
        export PM2_APP_NAME="${PM2_APP_NAME:-}"
        export BACKEND_PORT="${BACKEND_PORT:-}"
        export SHARED_ENV_PATH="$REMOTE_PATH/shared/.env"
        export NODE_VERSION="${NODE_VERSION:-24}"

        # Make hook executable and run it
        chmod +x .shipnode-pre-deploy.sh
        MISE_BIN="\$(command -v mise 2>/dev/null || true)"
        [ -z "\$MISE_BIN" ] && [ -x "\$HOME/.local/bin/mise" ] && MISE_BIN="\$HOME/.local/bin/mise"
        if [ -n "\$MISE_BIN" ]; then
            "\$MISE_BIN" exec "node@\$NODE_VERSION" -- ./.shipnode-pre-deploy.sh
        else
            ./.shipnode-pre-deploy.sh
        fi

        # Cleanup hook script
        rm -f .shipnode-pre-deploy.sh
ENDSSH

    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        success "Pre-deploy hook completed"
        return 0
    else
        error "Pre-deploy hook failed (exit code: $exit_code)"
        return 1
    fi
}

# Run post-deploy hook on remote server
# Returns: 0 on success, 1 on failure (but deployment continues)
run_post_deploy_hook() {
    local current_path="$REMOTE_PATH/current"
    local hook_script=${POST_DEPLOY_SCRIPT:-".shipnode/post-deploy.sh"}

    # Check if hook script exists locally
    if [ ! -f "$hook_script" ]; then
        return 0
    fi

    info "Running post-deploy hook: $hook_script"

    # Copy hook script to current directory
    if ! remote_copy "$hook_script" "$SSH_USER@$SSH_HOST:$current_path/.shipnode-post-deploy.sh" 2>&1; then
        warn "Failed to copy post-deploy hook to server"
        return 1
    fi

    # Execute hook on remote server with output streaming (not captured)
    remote_exec bash << ENDSSH
        set -e
        cd $current_path

        # Export environment variables for hook
        export RELEASE_PATH="$current_path"
        export REMOTE_PATH="$REMOTE_PATH"
        export PM2_APP_NAME="${PM2_APP_NAME:-}"
        export BACKEND_PORT="${BACKEND_PORT:-}"
        export SHARED_ENV_PATH="$REMOTE_PATH/shared/.env"
        export NODE_VERSION="${NODE_VERSION:-24}"

        # Make hook executable and run it
        chmod +x .shipnode-post-deploy.sh
        MISE_BIN="\$(command -v mise 2>/dev/null || true)"
        [ -z "\$MISE_BIN" ] && [ -x "\$HOME/.local/bin/mise" ] && MISE_BIN="\$HOME/.local/bin/mise"
        if [ -n "\$MISE_BIN" ]; then
            "\$MISE_BIN" exec "node@\$NODE_VERSION" -- ./.shipnode-post-deploy.sh
        else
            ./.shipnode-post-deploy.sh
        fi

        # Cleanup hook script
        rm -f .shipnode-post-deploy.sh
ENDSSH

    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        success "Post-deploy hook completed"
        return 0
    else
        warn "Post-deploy hook failed (deployment still successful, exit code: $exit_code)"
        return 1
    fi
}

# Database setup lives in lib/database.sh
