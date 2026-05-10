generate_sha512_password_hash() {
    local password="$1"

    if command -v mkpasswd &> /dev/null; then
        mkpasswd -m sha-512 "$password"
        return $?
    fi

    return 1
}

install_mkpasswd() {
    if command -v mkpasswd &> /dev/null; then
        return 0
    fi

    info "mkpasswd not found. Installing password hash helper..."

    local os_info pkg_manager
    IFS='|' read -r os_info pkg_manager <<< "$(detect_os)"

    if [ -z "$pkg_manager" ]; then
        warn "Could not detect package manager."
        return 1
    fi

    local sudo_cmd="sudo"
    if [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ]; then
        sudo_cmd=""
    elif ! command -v sudo &> /dev/null && [ "$pkg_manager" != "brew" ]; then
        warn "sudo is required to install mkpasswd with $pkg_manager."
        return 1
    fi

    local install_success=false
    local log_file="/tmp/shipnode_mkpasswd_install_$$.log"

    case "$pkg_manager" in
        apt)
            info "Using apt to install whois..."
            $sudo_cmd apt update &> "$log_file" && \
                $sudo_cmd apt install -y whois >> "$log_file" 2>&1 && install_success=true
            ;;
        dnf|yum)
            info "Using $pkg_manager to install whois..."
            $sudo_cmd "$pkg_manager" install -y whois &> "$log_file" && install_success=true
            ;;
        apk)
            info "Using apk to install whois..."
            $sudo_cmd apk add --no-cache whois &> "$log_file" && install_success=true
            ;;
        pacman)
            info "Using pacman to install whois..."
            $sudo_cmd pacman -S --needed --noconfirm whois &> "$log_file" && install_success=true
            ;;
        brew)
            info "Using Homebrew to install whois..."
            brew install whois &> "$log_file" && install_success=true
            ;;
        *)
            warn "Unsupported package manager: $pkg_manager"
            return 1
            ;;
    esac

    if [ "$install_success" = true ] && command -v mkpasswd &> /dev/null; then
        success "mkpasswd installed successfully"
        rm -f "$log_file"
        return 0
    fi

    warn "Failed to install mkpasswd."
    if [ -f "$log_file" ]; then
        warn "Installation log available at: $log_file"
    fi
    warn "Install it manually with your package manager (Debian/Ubuntu package: whois)."
    return 1
}

ensure_mkpasswd() {
    if generate_sha512_password_hash "shipnode-check" >/dev/null 2>&1; then
        return 0
    fi

    install_mkpasswd || error "mkpasswd not found. Password users are unavailable on this system. Use an SSH public key instead, or install mkpasswd manually (Debian/Ubuntu: sudo apt-get install whois)."
}

cmd_mkpasswd() {
    ensure_mkpasswd

    info "Generate password hash for users.yml"
    echo ""

    # Prompt for password (with confirmation)
    read -sp "Enter password: " password
    echo
    read -sp "Confirm password: " password2
    echo

    if [ "$password" != "$password2" ]; then
        error "Passwords do not match"
    fi

    if [ -z "$password" ]; then
        error "Password cannot be empty"
    fi

    # Generate hash
    local hash
    hash=$(generate_sha512_password_hash "$password") || error "Failed to generate password hash"

    echo ""
    success "Password hash generated:"
    echo ""
    echo "$hash"
    echo ""
    info "Add this to users.yml:"
    echo "  password: \"$hash\""
    echo ""
}
