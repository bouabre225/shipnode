validate_db_identifier() {
	local name="$1"
	local value="$2"

	if [[ ! "$value" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
		warn "$name must start with a letter or underscore and contain only letters, numbers, and underscores"
		return 1
	fi
}

setup_databases() {
	if [ "${DB_SETUP_ENABLED:-false}" = "true" ]; then
		case "${DB_TYPE:-postgresql}" in
			postgresql|postgres|pg)
				setup_postgresql
				;;
			mysql|mariadb)
				setup_mysql
				;;
			sqlite|sqlite3)
				setup_sqlite
				;;
			*)
				warn "Unsupported DB_TYPE '${DB_TYPE}'. Use postgresql, mysql, or sqlite"
				return 1
				;;
		esac
	fi

	if [ "${REDIS_SETUP_ENABLED:-false}" = "true" ]; then
		setup_redis
	fi
}

setup_postgresql() {
	# Validate required variables
	if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
		warn "PostgreSQL setup enabled but DB_NAME, DB_USER, or DB_PASSWORD not set in config"
		return 1
	fi

	validate_db_identifier "DB_NAME" "$DB_NAME" || return 1
	validate_db_identifier "DB_USER" "$DB_USER" || return 1

	info "Setting up PostgreSQL..."

	ssh_cmd -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
		DB_NAME="$DB_NAME" \
		DB_USER="$DB_USER" \
		DB_PASSWORD="$DB_PASSWORD" \
		bash <<'ENDSSH'
        set -e

        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        run_as_postgres() {
            if command -v sudo &> /dev/null; then
                sudo -u postgres "$@"
            else
                runuser -u postgres -- "$@"
            fi
        }

        if ! command -v psql &> /dev/null; then
            echo "Installing PostgreSQL..."
            $SUDO apt-get update
            $SUDO apt-get install -y postgresql postgresql-contrib
        else
            echo "PostgreSQL already installed: $(psql --version)"
        fi

        $SUDO systemctl start postgresql
        $SUDO systemctl enable postgresql

        echo "Configuring PostgreSQL for TCP connections..."

        PG_VERSION=$(run_as_postgres psql -t -c "SHOW server_version;" | cut -d. -f1 | tr -d ' ')
        PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
        PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

        if ! $SUDO grep -q "^listen_addresses.*localhost" "$PG_CONF"; then
            echo "Enabling TCP listener on localhost..."
            $SUDO sed -i "s/^#*listen_addresses.*/listen_addresses = 'localhost'/" "$PG_CONF"
        fi

        if ! $SUDO grep -q "host.*all.*all.*127.0.0.1/32.*md5" "$PG_HBA"; then
            echo "Adding TCP authentication rule..."
            $SUDO bash -c "echo 'host    all             all             127.0.0.1/32            md5' >> '$PG_HBA'"
        fi

        echo "Restarting PostgreSQL..."
        $SUDO systemctl restart postgresql

        echo "Creating database '$DB_NAME' and user '$DB_USER'..."
        DB_PASSWORD_SQL=$(printf "%s" "$DB_PASSWORD" | sed "s/'/''/g")

        run_as_postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
            run_as_postgres psql -c "CREATE DATABASE \"$DB_NAME\";"

        run_as_postgres psql -tc "SELECT 1 FROM pg_user WHERE usename = '$DB_USER'" | grep -q 1 || \
            run_as_postgres psql -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD_SQL';"

        run_as_postgres psql -c "ALTER USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD_SQL';"
        run_as_postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

        run_as_postgres psql -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";" 2>/dev/null || true
        run_as_postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$DB_USER\";" 2>/dev/null || true
        run_as_postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$DB_USER\";" 2>/dev/null || true

        echo "PostgreSQL setup complete. Database '$DB_NAME' is ready."
        echo "Connection string: postgresql://$DB_USER:[REDACTED]@localhost:5432/$DB_NAME"
ENDSSH

	success "PostgreSQL database '$DB_NAME' configured"
}

setup_mysql() {
	if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
		warn "MySQL setup enabled but DB_NAME, DB_USER, or DB_PASSWORD not set in config"
		return 1
	fi

	validate_db_identifier "DB_NAME" "$DB_NAME" || return 1
	validate_db_identifier "DB_USER" "$DB_USER" || return 1

	info "Setting up MySQL..."

	ssh_cmd -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
		DB_NAME="$DB_NAME" \
		DB_USER="$DB_USER" \
		DB_PASSWORD="$DB_PASSWORD" \
		bash <<'ENDSSH'
        set -e

        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        if ! command -v mysql &> /dev/null; then
            echo "Installing MySQL..."
            $SUDO apt-get update
            DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y mysql-server
        else
            echo "MySQL already installed: $(mysql --version)"
        fi

        $SUDO systemctl start mysql
        $SUDO systemctl enable mysql

        echo "Creating database '$DB_NAME' and user '$DB_USER'..."

        DB_PASSWORD_SQL=$(printf "%s" "$DB_PASSWORD" | sed "s/'/''/g")

        $SUDO mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD_SQL';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD_SQL';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

        echo "MySQL setup complete. Database '$DB_NAME' is ready."
        echo "Connection string: mysql://$DB_USER:[REDACTED]@localhost:3306/$DB_NAME"
ENDSSH

	success "MySQL database '$DB_NAME' configured"
}

setup_sqlite() {
	local sqlite_path="${DB_SQLITE_PATH:-}"

	if [ -z "$sqlite_path" ]; then
		if [ -z "${REMOTE_PATH:-}" ]; then
			warn "SQLite setup enabled but DB_SQLITE_PATH or REMOTE_PATH not set in config"
			return 1
		fi
		sqlite_path="$REMOTE_PATH/shared/database.sqlite"
	fi

	case "$sqlite_path" in
		/*) ;;
		*)
			warn "DB_SQLITE_PATH must be an absolute path"
			return 1
			;;
	esac

	case "$sqlite_path" in
		"$REMOTE_PATH/current/"*|"$REMOTE_PATH/releases/"*)
			warn "DB_SQLITE_PATH must not live inside current/ or releases/ because deploy cleanup can replace those paths"
			return 1
			;;
	esac

	info "Setting up SQLite..."

	ssh_cmd -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
		DB_SQLITE_PATH="$sqlite_path" \
		bash <<'ENDSSH'
        set -e

        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        if ! command -v sqlite3 &> /dev/null; then
            echo "Installing SQLite..."
            $SUDO apt-get update
            $SUDO apt-get install -y sqlite3
        else
            echo "SQLite already installed: $(sqlite3 --version | cut -d' ' -f1)"
        fi

        echo "Creating SQLite database at '$DB_SQLITE_PATH'..."
        DB_SQLITE_DIR="$(dirname "$DB_SQLITE_PATH")"
        $SUDO mkdir -p "$DB_SQLITE_DIR"
        $SUDO touch "$DB_SQLITE_PATH"
        $SUDO chown "$USER:$USER" "$DB_SQLITE_PATH" 2>/dev/null || true
        sqlite3 "$DB_SQLITE_PATH" "PRAGMA user_version;"

        echo "SQLite setup complete. Database '$DB_SQLITE_PATH' is ready."
        echo "Connection string: file:$DB_SQLITE_PATH"
ENDSSH

	success "SQLite database '$sqlite_path' configured"
}

setup_redis() {
	info "Setting up Redis..."

	ssh_cmd -o ServerAliveInterval=30 -o ServerAliveCountMax=5 -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" bash <<'ENDSSH'
        set -e

        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        if ! command -v redis-server &> /dev/null; then
            echo "Installing Redis..."
            $SUDO apt-get update
            $SUDO apt-get install -y redis-server
        else
            echo "Redis already installed: $(redis-server --version)"
        fi

        REDIS_CONF="/etc/redis/redis.conf"
        if [ -f "$REDIS_CONF" ]; then
            if ! $SUDO grep -q "^bind 127.0.0.1 ::1" "$REDIS_CONF"; then
                echo "Binding Redis to localhost..."
                $SUDO sed -i "s/^#*bind .*/bind 127.0.0.1 ::1/" "$REDIS_CONF"
            fi

            if ! $SUDO grep -q "^protected-mode yes" "$REDIS_CONF"; then
                echo "Enabling Redis protected mode..."
                $SUDO sed -i "s/^#*protected-mode .*/protected-mode yes/" "$REDIS_CONF"
            fi
        fi

        $SUDO systemctl start redis-server
        $SUDO systemctl enable redis-server

        echo "Redis setup complete. Connection string: redis://localhost:6379"
ENDSSH

	success "Redis configured"
}
