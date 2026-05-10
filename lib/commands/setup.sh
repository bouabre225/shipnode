cmd_setup() {
    load_config

    info "Setting up server $SSH_USER@$SSH_HOST..."

    # Check SSH connection
    if ! remote_exec "exit"; then
        error "Cannot connect to $SSH_USER@$SSH_HOST:$SSH_PORT"
    fi

    success "SSH connection successful"

    # Install Node.js, PM2, and Caddy
    info "Installing dependencies on server..."

    # Set default Node.js version if not specified
    local node_version="${NODE_VERSION:-lts}"

    # Extract major version if full version is provided (e.g., 22.14.0 -> 22)
    if [[ "$node_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        node_version=$(echo "$node_version" | cut -d. -f1)
        info "Extracted major version: $node_version"
    elif [[ "$node_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        node_version=$(echo "$node_version" | sed 's/^v//' | cut -d. -f1)
        info "Extracted major version: $node_version"
    fi

    [ "$node_version" = "lts" ] && node_version="24"
    info "Node.js version: $node_version"

    remote_exec bash -s "$node_version" << 'ENDSSH'
        NODE_VERSION="$1"
        set -e

        # Detect if running as root and set sudo prefix
        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        # Install jq for JSON manipulation
        if ! command -v jq &> /dev/null; then
            echo "Installing jq..."
            $SUDO apt-get update
            $SUDO apt-get install -y jq
        else
            echo "jq already installed: $(jq --version)"
        fi

        export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

        if ! command -v mise &> /dev/null; then
            echo "Installing per-project Node runtime..."
            curl https://mise.run | sh
            export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
        fi

        echo "Installing Node.js $NODE_VERSION for this deployment user..."
        mise install -y "node@$NODE_VERSION"

        if ! mise exec "node@$NODE_VERSION" -- npm --version >/dev/null 2>&1; then
            echo "Error: npm is required but was not installed"
            exit 1
        fi

        # Install PM2
        if ! mise exec "node@$NODE_VERSION" -- pm2 --version >/dev/null 2>&1; then
            echo "Installing PM2..."
            mise exec "node@$NODE_VERSION" -- npm install -g pm2
            mise exec "node@$NODE_VERSION" -- pm2 startup systemd -u $USER --hp $HOME || true
        else
            echo "PM2 already installed: $(mise exec "node@$NODE_VERSION" -- pm2 --version)"
        fi

        # Install Caddy
        if ! command -v caddy &> /dev/null; then
            echo "Installing Caddy..."
            $SUDO apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | $SUDO gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | $SUDO tee /etc/apt/sources.list.d/caddy-stable.list
            $SUDO apt update
            $SUDO apt install -y caddy
        else
            echo "Caddy already installed: $(caddy version)"
        fi
ENDSSH

    # Install package manager if project needs one other than npm
    if [ -f "package.json" ]; then
        local detected_pm=$(detect_pkg_manager)
        info "Detected package manager: $detected_pm"

        if [ "$detected_pm" != "npm" ]; then
            install_remote_pkg_manager "$detected_pm"
        else
            success "npm already available (comes with Node.js)"
        fi
    else
        info "No package.json found, skipping package manager setup"
    fi

    # Setup databases/caches if enabled
    setup_databases
    setup_database_backups

    success "Server setup complete"
    info "Ready to deploy with: shipnode deploy"
}

# Deploy application
