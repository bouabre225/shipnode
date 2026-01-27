#!/usr/bin/env bash

# Package manager detection and commands

# Detect package manager from lockfiles
detect_pkg_manager() {
    # Check for override in config
    if [ -n "$PKG_MANAGER" ]; then
        echo "$PKG_MANAGER"
        return
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
            echo "npm install --production"
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
