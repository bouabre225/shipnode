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
# Note: We install ALL dependencies (including dev) because many projects need
# devDependencies for build tools (TypeScript, Prisma, etc.) during deployment.
# Pruning devDependencies can happen after build/migration if needed.
get_pkg_install_cmd() {
    local pkg_manager=$1
    case "$pkg_manager" in
        bun)
            echo "bun install"
            ;;
        pnpm)
            echo "mise exec -- pnpm install"
            ;;
        yarn)
            echo "mise exec -- yarn install"
            ;;
        *)
            echo "mise exec -- npm install"
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
            echo "mise exec -- pnpm run $script"
            ;;
        yarn)
            echo "mise exec -- yarn run $script"
            ;;
        *)
            echo "mise exec -- npm run $script"
            ;;
    esac
}

# Determine interpreter for package manager
get_interpreter() {
    local pkg_manager=$1
    case "$pkg_manager" in
        bun)  echo "bun" ;;
        pnpm) echo "pnpm" ;;
        yarn) echo "yarn" ;;
        *)    echo "npm" ;;
    esac
}

# Generate PM2 ecosystem file - checks for ejected templates first
generate_ecosystem_file() {
    local pkg_manager=$1
    local app_name=$2
    local cwd=$3
    local interpreter
    interpreter=$(get_interpreter "$pkg_manager")

    local template_file
    template_file=$(resolve_template "ecosystem.config.cjs")

    if [ -n "$template_file" ]; then
        info "Using custom PM2 template: $template_file"
        render_template "$template_file" \
            APP_NAME "$app_name" \
            INTERPRETER "$interpreter" \
            REMOTE_PATH "$cwd" \
            BACKEND_PORT "${BACKEND_PORT:-3000}"
    else
        cat << EOF
module.exports = {
  apps: [{
    name: "$app_name",
    script: "mise",
    args: "exec -- $interpreter start",
    cwd: "$cwd",
    autorestart: true,
    max_restarts: 10,
    min_uptime: '10s',
    env: {
      PATH: process.env.HOME + "/.local/bin:" + process.env.HOME + "/.local/share/mise/shims:" + process.env.PATH
    }
  }]
};
EOF
    fi
}

# Install package manager on remote server
install_remote_pkg_manager() {
    local pkg_manager=$1
    local node_version="${NODE_VERSION:-24}"
    [ "$node_version" = "lts" ] && node_version="24"

    # npm comes with Node.js, no need to install separately
    if [ "$pkg_manager" = "npm" ]; then
        return 0
    fi

    info "Installing $pkg_manager on remote server..."

    if remote_exec bash << ENDSSH
        set -e

        export PATH="\$HOME/.local/bin:\$HOME/.local/share/mise/shims:\$PATH"

        # Check if already installed
        if mise exec "node@$node_version" -- $pkg_manager --version > /dev/null 2>&1; then
            echo "ALREADY_INSTALLED:\$(mise exec "node@$node_version" -- $pkg_manager --version 2>/dev/null || mise exec "node@$node_version" -- $pkg_manager -v)"
            exit 0
        fi

        # Install based on package manager type
        case "$pkg_manager" in
            yarn)
                echo "Installing yarn..."
                mise exec "node@$node_version" -- npm install -g yarn
                ;;
            pnpm)
                echo "Installing pnpm..."
                mise exec "node@$node_version" -- npm install -g pnpm
                ;;
            bun)
                echo "Installing bun..."
                curl -fsSL https://bun.sh/install | bash
                # Add bun to PATH for current session
                export BUN_INSTALL="\$HOME/.bun"
                export PATH="\$BUN_INSTALL/bin:\$PATH"
                ;;
            *)
                echo "Unknown package manager: $pkg_manager"
                exit 1
                ;;
        esac

        # Verify installation - check both command -v and bun-specific path
        if mise exec "node@$node_version" -- $pkg_manager --version > /dev/null 2>&1; then
            echo "NEWLY_INSTALLED:\$(mise exec "node@$node_version" -- $pkg_manager --version 2>/dev/null || mise exec "node@$node_version" -- $pkg_manager -v)"
        elif [ "$pkg_manager" = "bun" ] && [ -x "\$HOME/.bun/bin/bun" ]; then
            echo "NEWLY_INSTALLED:\$(\$HOME/.bun/bin/bun --version)"
        else
            echo "Failed to install $pkg_manager"
            exit 1
        fi
ENDSSH
    then
        success "$pkg_manager is available on remote server"
    else
        error "Failed to install $pkg_manager on remote server"
    fi
}

# Verify package manager is installed on remote server
verify_remote_pkg_manager() {
    local pkg_manager=$1
    local node_version="${NODE_VERSION:-24}"
    [ "$node_version" = "lts" ] && node_version="24"

    info "Verifying $pkg_manager is installed on remote server..."

    if [ "$pkg_manager" = "bun" ]; then
        if remote_exec "command -v bun > /dev/null 2>&1 || [ -x \"\$HOME/.bun/bin/bun\" ]"; then
            success "$pkg_manager is available on remote server"
            return 0
        fi
    elif remote_exec "export PATH=\"\$HOME/.local/bin:\$HOME/.local/share/mise/shims:\$PATH\"; mise exec node@$node_version -- $pkg_manager --version > /dev/null 2>&1"; then
        success "$pkg_manager is available on remote server"
        return 0
    fi

    if true; then
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
