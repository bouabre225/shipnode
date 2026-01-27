setup_postgresql() {
	# Check if PostgreSQL setup is enabled
	if [ "${DB_SETUP_ENABLED:-false}" != "true" ]; then
		return 0
	fi

	# Validate required variables
	if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
		warn "PostgreSQL setup enabled but DB_NAME, DB_USER, or DB_PASSWORD not set in config"
		return 1
	fi

	info "Setting up PostgreSQL..."

	ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
		DB_NAME="$DB_NAME" \
		DB_USER="$DB_USER" \
		DB_PASSWORD="$DB_PASSWORD" \
		bash <<'ENDSSH'
        set -e

        # Detect if running as root and set sudo prefix
        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        # Install PostgreSQL
        if ! command -v psql &> /dev/null; then
            echo "Installing PostgreSQL..."
            $SUDO apt-get update
            $SUDO apt-get install -y postgresql postgresql-contrib
        else
            echo "PostgreSQL already installed: $(psql --version)"
        fi

        # Ensure PostgreSQL is running
        $SUDO systemctl start postgresql
        $SUDO systemctl enable postgresql

        # Create database and user
        echo "Creating database '$DB_NAME' and user '$DB_USER'..."

        # Create database if it doesn't exist
        $SUDO -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
            $SUDO -u postgres psql -c "CREATE DATABASE \"$DB_NAME\";"

        # Create user if it doesn't exist
        $SUDO -u postgres psql -tc "SELECT 1 FROM pg_user WHERE usename = '$DB_USER'" | grep -q 1 || \
            $SUDO -u postgres psql -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"

        # Update password if user already exists
        $SUDO -u postgres psql -c "ALTER USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"

        # Grant privileges
        $SUDO -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

        # For PostgreSQL 15+, grant schema privileges
        $SUDO -u postgres psql -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";" 2>/dev/null || true
        $SUDO -u postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"$DB_USER\";" 2>/dev/null || true
        $SUDO -u postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"$DB_USER\";" 2>/dev/null || true

        echo "PostgreSQL setup complete. Database '$DB_NAME' is ready."
        echo "Connection string: postgresql://$DB_USER:[REDACTED]@localhost:5432/$DB_NAME"
ENDSSH

	success "PostgreSQL database '$DB_NAME' configured"
}

# ============================================================================

# TODO: add a redis
