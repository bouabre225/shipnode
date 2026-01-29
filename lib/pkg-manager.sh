#!/usr/bin/env bash

# Package manager detection and commands

# Detect package manager from lockfiles
detect_pkg_manager() {
    # Check for override in config
    if [ -n "$PKG_MANAGER" ]; then
        # Validate override value
        case "$PKG_MANAGER" in
            npm|yarn|pnpm|bun)
                echo "$PKG_MANAGER"
                return
                ;;
            *)
                warn "Invalid PKG_MANAGER value: '$PKG_MANAGER'. Must be one of: npm, yarn, pnpm, bun"
                warn "Falling back to lockfile detection..."
                ;;
        esac
    fi

    # Auto-detect from lockfiles
    if [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
        echo "bun"
    elif [ -f "pnpm-lock.yaml" ]; then
        echo "pnpm"
    elif [ -f "yarn.lock" ]; then
        echo "yarn"
    else
        echo "npm"
    fi
}

# Get install command for package manager
get_pkg_install_cmd() {
    local pkg_manager=$1
    case "$pkg_manager" in
        bun)
            echo "bun install --production"
            ;;
        pnpm)
            echo "pnpm install --prod"
            ;;
        yarn)
            echo "yarn install --production"
            ;;
        *)
            echo "npm install --omit=dev"
            ;;
    esac
}

# Get run command for package manager
get_pkg_run_cmd() {
    local pkg_manager=$1
    local script=$2
    case "$pkg_manager" in
        bun)
            echo "bun run $script"
            ;;
        pnpm)
            echo "pnpm run $script"
            ;;
        yarn)
            echo "yarn run $script"
            ;;
        *)
            echo "npm run $script"
            ;;
    esac
}

# Get PM2 start command for package manager
get_pkg_start_cmd() {
    local pkg_manager=$1
    local app_name=$2
    case "$pkg_manager" in
        bun)
            echo "pm2 start bun --name \"$app_name\" -- start"
            ;;
        pnpm)
            echo "pm2 start pnpm --name \"$app_name\" -- start"
            ;;
        yarn)
            echo "pm2 start yarn --name \"$app_name\" -- start"
            ;;
        *)
            echo "pm2 start npm --name \"$app_name\" -- start"
            ;;
    esac
}

# Verify package manager is installed on remote server
verify_remote_pkg_manager() {
    local pkg_manager=$1
    local node_version="${NODE_VERSION:-lts}"

    info "Verifying $pkg_manager is installed on remote server..."

    if ! ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "command -v $pkg_manager > /dev/null 2>&1"; then
        error "$pkg_manager is not installed on the remote server"
        echo ""
        echo "Please install $pkg_manager on the remote server:"
        case "$pkg_manager" in
            bun)
                echo "  # SSH into the server and run:"
                echo "  curl -fsSL https://bun.sh/install | bash"
                echo ""
                echo "  # Or run setup to install all dependencies:"
                echo "  shipnode setup"
                ;;
            pnpm)
                echo "  # SSH into the server and run:"
                echo "  npm install -g pnpm"
                echo ""
                echo "  # Or run setup to install Node.js and then pnpm:"
                echo "  shipnode setup"
                ;;
            yarn)
                echo "  # SSH into the server and run:"
                echo "  npm install -g yarn"
                echo ""
                echo "  # Or run setup to install Node.js and then yarn:"
                echo "  shipnode setup"
                ;;
            npm)
                echo "  # npm should be installed with Node.js (version: $node_version)"
                echo "  # SSH into the server and run:"
                echo "  curl -fsSL https://deb.nodesource.com/setup_${node_version}.x | sudo -E bash -"
                echo "  sudo apt-get install -y nodejs"
                echo ""
                echo "  # Or run setup to install all dependencies:"
                echo "  shipnode setup"
                ;;
        esac
        echo ""
        exit 1
    fi

    success "$pkg_manager is available on remote server"
}
