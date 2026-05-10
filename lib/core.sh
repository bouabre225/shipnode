#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ShipNode version
VERSION="1.4.6"

# SSH multiplexing for connection reuse
SSH_CONTROL_PATH="/tmp/shipnode-ssh-%r@%h:%p"

start_ssh_multiplex() {
    if [ -n "${SSH_USER:-}" ] && [ -n "${SSH_HOST:-}" ]; then
        ssh -o ControlMaster=auto -o ControlPath="$SSH_CONTROL_PATH" \
            -o ControlPersist=300 -fN -p "${SSH_PORT:-22}" "$SSH_USER@$SSH_HOST" 2>/dev/null || true
    fi
}

stop_ssh_multiplex() {
    ssh -o ControlPath="$SSH_CONTROL_PATH" -O exit \
        -p "${SSH_PORT:-22}" "${SSH_USER:-}@${SSH_HOST:-}" 2>/dev/null || true
}

ssh_cmd() {
    ssh -o ControlPath="$SSH_CONTROL_PATH" "$@"
}

# High-level SSH helpers using multiplexed connection
remote_exec() {
    ssh_cmd -T -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "$@"
}

remote_copy() {
    scp -o ControlPath="$SSH_CONTROL_PATH" -P "$SSH_PORT" "$@"
}

remote_rsync() {
    rsync -e "ssh -o ControlPath=$SSH_CONTROL_PATH -p $SSH_PORT" "$@"
}

export SSH_CONTROL_PATH

# Helper functions
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

info() {
    echo -e "${BLUE}→ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Gum detection for enhanced UI
has_gum() {
    command -v gum &> /dev/null
}

# Check if enhanced UI is available
USE_GUM=false
if has_gum; then
    USE_GUM=true
fi

# Detect operating system and package manager
detect_os() {
    local os_type=""
    local pkg_manager=""
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt &> /dev/null; then
            os_type="debian"
            pkg_manager="apt"
        elif command -v dnf &> /dev/null; then
            os_type="redhat"
            pkg_manager="dnf"
        elif command -v yum &> /dev/null; then
            os_type="redhat"
            pkg_manager="yum"
        elif command -v apk &> /dev/null; then
            os_type="alpine"
            pkg_manager="apk"
        elif command -v pacman &> /dev/null; then
            os_type="arch"
            pkg_manager="pacman"
        else
            os_type="unknown"
            pkg_manager=""
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="macos"
        if command -v brew &> /dev/null; then
            pkg_manager="brew"
        else
            pkg_manager=""
        fi
    else
        os_type="unknown"
        pkg_manager=""
    fi
    
    echo "${os_type}|${pkg_manager}"
}

# Install Gum UI framework
install_gum() {
    # Check if already installed
    if has_gum; then
        info "Gum is already installed ($(gum --version 2>&1 | head -n1))"
        return 0
    fi
    
    info "Installing Gum for enhanced UI experience..."
    
    # Detect OS and package manager
    local os_info pkg_manager
    IFS='|' read -r os_info pkg_manager <<< "$(detect_os)"
    
    if [ -z "$pkg_manager" ]; then
        warn "Could not detect package manager. Gum installation skipped."
        warn "You can install Gum manually from: https://github.com/charmbracelet/gum"
        return 1
    fi
    
    local install_success=false
    local log_file="/tmp/shipnode_gum_install_$$.log"
    local sudo_cmd="sudo"
    if [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ]; then
        sudo_cmd=""
    elif ! command -v sudo &> /dev/null; then
        warn "sudo is required to install Gum with $pkg_manager."
        warn "Install Gum manually from: https://github.com/charmbracelet/gum"
        return 1
    fi
    
    case "$pkg_manager" in
        apt)
            info "Using apt to install Gum..."
            {
                $sudo_cmd apt update && \
                $sudo_cmd apt install -y curl gpg && \
                $sudo_cmd mkdir -p /etc/apt/keyrings && \
                curl -fsSL https://repo.charm.sh/apt/gpg.key | $sudo_cmd gpg --dearmor -o /etc/apt/keyrings/charm.gpg && \
                echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | $sudo_cmd tee /etc/apt/sources.list.d/charm.list > /dev/null && \
                $sudo_cmd apt update && \
                $sudo_cmd apt install -y gum
            } &> "$log_file" && install_success=true
            ;;
        dnf|yum)
            info "Using $pkg_manager to install Gum..."
            {
                echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | $sudo_cmd tee /etc/yum.repos.d/charm.repo > /dev/null && \
                $sudo_cmd "$pkg_manager" install -y gum
            } &> "$log_file" && install_success=true
            ;;
        brew)
            info "Using Homebrew to install Gum..."
            brew install gum &> "$log_file" && install_success=true
            ;;
        apk)
            info "Using apk to install Gum..."
            $sudo_cmd apk add --no-cache gum &> "$log_file" && install_success=true
            ;;
        pacman)
            info "Using pacman to install Gum..."
            $sudo_cmd pacman -S --needed --noconfirm gum &> "$log_file" && install_success=true
            ;;
        *)
            warn "Unsupported package manager: $pkg_manager"
            return 1
            ;;
    esac
    
    if [ "$install_success" = true ] && has_gum; then
        success "Gum installed successfully! ($(gum --version 2>&1 | head -n1))"
        # Update the global flag
        USE_GUM=true
        rm -f "$log_file"
        return 0
    else
        warn "Failed to install Gum. The interactive wizard will use fallback mode."
        if [ -f "$log_file" ]; then
            warn "Installation log available at: $log_file"
        fi
        warn "You can install Gum manually from: https://github.com/charmbracelet/gum"
        return 1
    fi
}

# Build rsync exclude arguments from built-in defaults + .shipnodeignore
# Returns: string of --exclude flags or --exclude-from flag
get_rsync_excludes() {
    if [ -f ".shipnodeignore" ]; then
        echo "--exclude-from .shipnodeignore"
    else
        echo "--exclude node_modules --exclude .env --exclude .git --exclude .gitignore --exclude shipnode.conf --exclude '*.log' --exclude .shipnode"
    fi
}

# Template rendering - replaces {{VAR}} placeholders using sed
# Usage: render_template <template_file> [VAR_NAME VAR_VALUE]...
# Example: render_template file.tmpl APP_NAME myapp BACKEND_PORT 3000
render_template() {
    local template_file="$1"
    shift

    if [ ! -f "$template_file" ]; then
        error "Template file not found: $template_file"
    fi

    local content
    content=$(cat "$template_file")

    while [ $# -ge 2 ]; do
        local var_name="$1"
        local var_value="$2"
        shift 2
        content=$(echo "$content" | sed "s|{{${var_name}}}|${var_value}|g")
    done

    echo "$content"
}

# Find the best template file for a given config type
# Resolution order:
#   1. .shipnode/templates/<filename> (user customized)
#   2. <filename> in project root (user provided)
#   3. Returns empty string (caller falls back to built-in)
resolve_template() {
    local filename="$1"

    if [ -f ".shipnode/templates/$filename" ]; then
        echo ".shipnode/templates/$filename"
    elif [ -f "$filename" ]; then
        echo "$filename"
    fi
}

# Release management helper functions
