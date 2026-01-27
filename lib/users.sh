# USER PROVISIONING FUNCTIONS
# ============================================================================

# Validation helpers
validate_username() {
    local username=$1
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]] || [ ${#username} -gt 32 ]; then
        return 1
    fi
    return 0
}

validate_password_hash() {
    local hash=$1
    # Check if it's a valid crypt format (starts with $)
    if [[ "$hash" =~ ^\$[0-9]+\$ ]]; then
        return 0
    fi
    return 1
}

validate_ssh_key() {
    local key=$1
    # Check if key starts with valid key type
    if [[ "$key" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)\ .+ ]]; then
        return 0
    fi
    return 1
}

# Reusable yes/no prompt with default support
prompt_yes_no() {
    local prompt=$1 default=${2:-n}
    if [ "$default" = "y" ]; then
        read -p "$prompt (Y/n) " -n 1 -r
    else
        read -p "$prompt (y/N) " -n 1 -r
    fi
    echo
    [ -z "$REPLY" ] && { [ "$default" = "y" ] && return 0 || return 1; }
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Generate password hash (reuses cmd_mkpasswd logic)
generate_password_hash() {
    local password=$1
    # Check if mkpasswd is available
    if ! command -v mkpasswd &> /dev/null; then
        error "mkpasswd not found. Install it with: sudo apt-get install whois"
    fi
    mkpasswd -m sha-512 "$password"
}

# Validate email address
validate_email() {
    local email=$1
    if [[ "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        return 0
    fi
    return 1
}

# Read SSH key from file
read_key_file() {
    local file_path=$1
    # Expand tilde to home directory
    file_path="${file_path/#\~/$HOME}"

    if [ ! -f "$file_path" ]; then
        echo ""
        return 1
    fi

    cat "$file_path"
    return 0
}

# ============================================================================
