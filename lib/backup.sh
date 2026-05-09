backup_is_enabled() {
    [ "${DB_BACKUP_ENABLED:-false}" = "true" ]
}

backup_sqlite_path() {
    if [ -n "${DB_SQLITE_PATH:-}" ]; then
        echo "$DB_SQLITE_PATH"
    else
        echo "$REMOTE_PATH/shared/database.sqlite"
    fi
}

backup_schedule_calendar() {
    case "${DB_BACKUP_SCHEDULE:-daily}" in
        hourly)
            echo "hourly"
            ;;
        daily)
            echo "daily"
            ;;
        weekly)
            echo "weekly"
            ;;
        *)
            echo "${DB_BACKUP_SCHEDULE:-daily}"
            ;;
    esac
}

validate_backup_config() {
    if ! backup_is_enabled; then
        warn "Database backups are disabled. Set DB_BACKUP_ENABLED=true in $SHIPNODE_CONFIG_FILE"
        return 1
    fi

    if [ -z "${DB_BACKUP_S3_BUCKET:-}" ]; then
        warn "DB_BACKUP_S3_BUCKET is required when DB_BACKUP_ENABLED=true"
        return 1
    fi

    if ! [[ "${DB_BACKUP_RETENTION_DAYS:-14}" =~ ^[0-9]+$ ]]; then
        warn "DB_BACKUP_RETENTION_DAYS must be a number"
        return 1
    fi

    case "${DB_TYPE:-postgresql}" in
        postgresql|postgres|pg|mysql|mariadb|sqlite|sqlite3)
            ;;
        *)
            warn "Unsupported DB_TYPE '${DB_TYPE:-}'. Backups support postgresql, mysql, and sqlite"
            return 1
            ;;
    esac

    case "${DB_TYPE:-postgresql}" in
        postgresql|postgres|pg|mysql|mariadb)
            if [ -z "${DB_NAME:-}" ] || [ -z "${DB_USER:-}" ]; then
                warn "DB_NAME and DB_USER are required for ${DB_TYPE:-postgresql} backups"
                return 1
            fi
            ;;
        sqlite|sqlite3)
            local sqlite_path
            sqlite_path="$(backup_sqlite_path)"
            case "$sqlite_path" in
                /*) ;;
                *)
                    warn "DB_SQLITE_PATH must be absolute for SQLite backups"
                    return 1
                    ;;
            esac
            ;;
    esac
}

install_backup_dependencies() {
    validate_backup_config || return 1

    info "Installing database backup dependencies..."

    ssh_cmd -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
        DB_TYPE="${DB_TYPE:-postgresql}" \
        bash <<'ENDSSH'
        set -e

        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        install_packages() {
            $SUDO apt-get update
            DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$@"
        }

        packages="awscli gzip"
        case "$DB_TYPE" in
            postgresql|postgres|pg)
                packages="$packages postgresql-client"
                ;;
            mysql|mariadb)
                packages="$packages default-mysql-client"
                ;;
            sqlite|sqlite3)
                packages="$packages sqlite3"
                ;;
        esac

        missing=""
        for package in $packages; do
            case "$package" in
                awscli)
                    command -v aws >/dev/null 2>&1 || missing="$missing $package"
                    ;;
                gzip)
                    command -v gzip >/dev/null 2>&1 || missing="$missing $package"
                    ;;
                postgresql-client)
                    command -v pg_dump >/dev/null 2>&1 || missing="$missing $package"
                    ;;
                default-mysql-client)
                    command -v mysqldump >/dev/null 2>&1 || missing="$missing $package"
                    ;;
                sqlite3)
                    command -v sqlite3 >/dev/null 2>&1 || missing="$missing $package"
                    ;;
            esac
        done

        if [ -n "$missing" ]; then
            echo "Installing:$missing"
            install_packages $missing
        else
            echo "Backup dependencies already installed"
        fi
ENDSSH
}

write_backup_files() {
    validate_backup_config || return 1

    local backup_prefix="${DB_BACKUP_S3_PREFIX:-${PM2_APP_NAME:-$(basename "$REMOTE_PATH")}}"
    local backup_dir="${DB_BACKUP_LOCAL_DIR:-$REMOTE_PATH/shared/backups}"
    local retention_days="${DB_BACKUP_RETENTION_DAYS:-14}"
    local sqlite_path=""
    if [ "${DB_TYPE:-postgresql}" = "sqlite" ] || [ "${DB_TYPE:-postgresql}" = "sqlite3" ]; then
        sqlite_path="$(backup_sqlite_path)"
    fi

    info "Writing remote backup script..."

    ssh_cmd -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
        REMOTE_PATH="$REMOTE_PATH" \
        SHARED_ENV_PATH="${SHARED_ENV_PATH:-$REMOTE_PATH/shared/.env}" \
        DB_TYPE="${DB_TYPE:-postgresql}" \
        DB_NAME="${DB_NAME:-}" \
        DB_USER="${DB_USER:-}" \
        DB_PASSWORD="${DB_PASSWORD:-}" \
        DB_SQLITE_PATH="$sqlite_path" \
        DB_BACKUP_S3_BUCKET="$DB_BACKUP_S3_BUCKET" \
        DB_BACKUP_S3_PREFIX="$backup_prefix" \
        DB_BACKUP_S3_ENDPOINT="${DB_BACKUP_S3_ENDPOINT:-}" \
        DB_BACKUP_LOCAL_DIR="$backup_dir" \
        DB_BACKUP_RETENTION_DAYS="$retention_days" \
        AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}" \
        AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}" \
        AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-}" \
        bash <<'ENDSSH'
        set -e

        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        SHARED_DIR="$REMOTE_PATH/shared"
        SCRIPT_PATH="$SHARED_DIR/shipnode-backup.sh"
        ENV_PATH="$SHARED_DIR/shipnode-backup.env"

        mkdir -p "$SHARED_DIR" "$DB_BACKUP_LOCAL_DIR"

        : > "$ENV_PATH"
        chmod 600 "$ENV_PATH"
        write_env_var() {
            local name="$1"
            local value="${!name:-}"
            printf '%s=%q\n' "$name" "$value" >> "$ENV_PATH"
        }

        for name in \
            REMOTE_PATH SHARED_ENV_PATH DB_TYPE DB_NAME DB_USER DB_PASSWORD DB_SQLITE_PATH \
            DB_BACKUP_S3_BUCKET DB_BACKUP_S3_PREFIX DB_BACKUP_S3_ENDPOINT \
            DB_BACKUP_LOCAL_DIR DB_BACKUP_RETENTION_DAYS \
            AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION; do
            write_env_var "$name"
        done

        cat > "$SCRIPT_PATH" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

BACKUP_ENV_PATH="${BACKUP_ENV_PATH:-__BACKUP_ENV_PATH__}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

load_env_file() {
    local file="$1"
    if [ -f "$file" ]; then
        set -a
        # shellcheck disable=SC1090
        source "$file"
        set +a
    fi
}

load_env_file "$BACKUP_ENV_PATH"
load_env_file "${SHARED_ENV_PATH:-$REMOTE_PATH/shared/.env}"

require_value() {
    local name="$1"
    if [ -z "${!name:-}" ]; then
        echo "Missing required value: $name" >&2
        exit 1
    fi
}

aws_args=()
if [ -n "${DB_BACKUP_S3_ENDPOINT:-}" ]; then
    aws_args+=(--endpoint-url "$DB_BACKUP_S3_ENDPOINT")
fi

run_backup() {
    require_value DB_BACKUP_S3_BUCKET

    local timestamp backup_name backup_path s3_prefix s3_uri tmp_copy
    timestamp="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "${DB_BACKUP_LOCAL_DIR:-$REMOTE_PATH/shared/backups}"

    case "${DB_TYPE:-postgresql}" in
        postgresql|postgres|pg)
            require_value DB_NAME
            require_value DB_USER
            backup_name="${DB_NAME}-postgresql-${timestamp}.sql.gz"
            backup_path="${DB_BACKUP_LOCAL_DIR:-$REMOTE_PATH/shared/backups}/$backup_name"
            log "Creating PostgreSQL backup: $backup_name"
            PGPASSWORD="${DB_PASSWORD:-}" pg_dump \
                -h "${DB_HOST:-localhost}" \
                -p "${DB_PORT:-5432}" \
                -U "$DB_USER" \
                "$DB_NAME" | gzip -c > "$backup_path"
            ;;
        mysql|mariadb)
            require_value DB_NAME
            require_value DB_USER
            backup_name="${DB_NAME}-mysql-${timestamp}.sql.gz"
            backup_path="${DB_BACKUP_LOCAL_DIR:-$REMOTE_PATH/shared/backups}/$backup_name"
            log "Creating MySQL backup: $backup_name"
            MYSQL_PWD="${DB_PASSWORD:-}" mysqldump \
                -h "${DB_HOST:-localhost}" \
                -P "${DB_PORT:-3306}" \
                -u "$DB_USER" \
                "$DB_NAME" | gzip -c > "$backup_path"
            ;;
        sqlite|sqlite3)
            require_value DB_SQLITE_PATH
            backup_name="$(basename "$DB_SQLITE_PATH")-sqlite-${timestamp}.sqlite.gz"
            backup_path="${DB_BACKUP_LOCAL_DIR:-$REMOTE_PATH/shared/backups}/$backup_name"
            tmp_copy="${backup_path%.gz}.tmp"
            log "Creating SQLite backup: $backup_name"
            sqlite3 "$DB_SQLITE_PATH" ".backup '$tmp_copy'"
            gzip -c "$tmp_copy" > "$backup_path"
            rm -f "$tmp_copy"
            ;;
        *)
            echo "Unsupported DB_TYPE: ${DB_TYPE:-}" >&2
            exit 1
            ;;
    esac

    s3_prefix="${DB_BACKUP_S3_PREFIX:-$(basename "$REMOTE_PATH")}"
    s3_prefix="${s3_prefix#/}"
    s3_prefix="${s3_prefix%/}"
    if [ -n "$s3_prefix" ]; then
        s3_uri="s3://${DB_BACKUP_S3_BUCKET}/${s3_prefix}/${backup_name}"
    else
        s3_uri="s3://${DB_BACKUP_S3_BUCKET}/${backup_name}"
    fi

    log "Uploading backup to $s3_uri"
    aws "${aws_args[@]}" s3 cp "$backup_path" "$s3_uri"

    if [ "${DB_BACKUP_RETENTION_DAYS:-0}" -gt 0 ]; then
        find "${DB_BACKUP_LOCAL_DIR:-$REMOTE_PATH/shared/backups}" -type f -mtime +"${DB_BACKUP_RETENTION_DAYS}" -name '*.gz' -delete
    fi

    log "Backup complete: $s3_uri"
}

list_backups() {
    require_value DB_BACKUP_S3_BUCKET
    local s3_prefix="${DB_BACKUP_S3_PREFIX:-$(basename "$REMOTE_PATH")}"
    s3_prefix="${s3_prefix#/}"
    s3_prefix="${s3_prefix%/}"

    if [ -n "$s3_prefix" ]; then
        aws "${aws_args[@]}" s3 ls "s3://${DB_BACKUP_S3_BUCKET}/${s3_prefix}/"
    else
        aws "${aws_args[@]}" s3 ls "s3://${DB_BACKUP_S3_BUCKET}/"
    fi
}

case "${1:-run}" in
    run)
        run_backup
        ;;
    list)
        list_backups
        ;;
    *)
        echo "Usage: $0 [run|list]" >&2
        exit 1
        ;;
esac
SCRIPT

        sed -i "s|__BACKUP_ENV_PATH__|$ENV_PATH|g" "$SCRIPT_PATH"
        chmod 700 "$SCRIPT_PATH"
ENDSSH
}

setup_backup_timer() {
    validate_backup_config || return 1

    local calendar
    calendar="$(backup_schedule_calendar)"

    info "Configuring database backup timer ($calendar)..."

    ssh_cmd -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
        REMOTE_PATH="$REMOTE_PATH" \
        DB_BACKUP_SCHEDULE_CALENDAR="$calendar" \
        bash <<'ENDSSH'
        set -e

        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        SERVICE_PATH="/etc/systemd/system/shipnode-backup.service"
        TIMER_PATH="/etc/systemd/system/shipnode-backup.timer"
        SCRIPT_PATH="$REMOTE_PATH/shared/shipnode-backup.sh"
        RUN_USER="$USER"

        $SUDO tee "$SERVICE_PATH" >/dev/null <<SERVICE
[Unit]
Description=ShipNode database backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=$RUN_USER
ExecStart=$SCRIPT_PATH run
SERVICE

        $SUDO tee "$TIMER_PATH" >/dev/null <<TIMER
[Unit]
Description=Run ShipNode database backups

[Timer]
OnCalendar=$DB_BACKUP_SCHEDULE_CALENDAR
Persistent=true

[Install]
WantedBy=timers.target
TIMER

        $SUDO systemctl daemon-reload
        $SUDO systemctl enable --now shipnode-backup.timer
ENDSSH

    success "Database backup timer configured"
}

setup_database_backups() {
    if ! backup_is_enabled; then
        return 0
    fi

    install_backup_dependencies
    write_backup_files
    setup_backup_timer
}

run_database_backup() {
    validate_backup_config || return 1
    write_backup_files

    info "Running database backup now..."

    remote_exec "$REMOTE_PATH/shared/shipnode-backup.sh" run
}

list_database_backups() {
    validate_backup_config || return 1
    write_backup_files

    info "Listing S3 backups..."

    remote_exec "$REMOTE_PATH/shared/shipnode-backup.sh" list
}

show_database_backup_status() {
    validate_backup_config || return 1

    info "Checking database backup status..."

    ssh_cmd -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
        REMOTE_PATH="$REMOTE_PATH" \
        bash <<'ENDSSH'
        set -e

        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        echo ""
        echo "Timer:"
        $SUDO systemctl --no-pager --full status shipnode-backup.timer || true

        echo ""
        echo "Recent backup logs:"
        $SUDO journalctl -u shipnode-backup.service -n 30 --no-pager || true

        echo ""
        echo "Local backups:"
        ls -lh "$REMOTE_PATH/shared/backups" 2>/dev/null || true
ENDSSH
}
