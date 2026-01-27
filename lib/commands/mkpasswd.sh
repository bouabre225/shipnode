cmd_mkpasswd() {
    # Check if mkpasswd is available
    if ! command -v mkpasswd &> /dev/null; then
        error "mkpasswd not found. Install it with: sudo apt-get install whois"
    fi

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
    local hash=$(mkpasswd -m sha-512 "$password")

    echo ""
    success "Password hash generated:"
    echo ""
    echo "$hash"
    echo ""
    info "Add this to users.yml:"
    echo "  password: \"$hash\""
    echo ""
}

