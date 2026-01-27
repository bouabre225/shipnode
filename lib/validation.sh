# INPUT VALIDATION FUNCTIONS
# ============================================================================

# Validate IP address or hostname
# Accepts both IPv4 addresses and RFC-compliant hostnames
# Args:
#   $1: IP address or hostname to validate
# Returns:
#   Exit code 0 if valid, 1 if invalid
# Examples:
#   192.168.1.1 → valid
#   example.com → valid
#   999.999.999.999 → invalid
validate_ip_or_hostname() {
    local input=$1
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Check if it's a valid IPv4 address
    if [[ "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Validate each octet is 0-255
        IFS='.' read -ra OCTETS <<< "$input"
        for octet in "${OCTETS[@]}"; do
            # Ensure the octet contains only digits
            if ! [[ "$octet" =~ ^[0-9]+$ ]]; then
                return 1
            fi
            # Use base-10 to avoid octal interpretation of leading zeros
            if ((10#$octet < 0 || 10#$octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    
    # Check if it's a valid hostname
    if [[ "$input" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    
    return 1
}

# Validate port number
validate_port() {
    local port=$1
    
    if [ -z "$port" ]; then
        return 1
    fi
    
    # Must be numeric
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Must be in valid range
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    
    return 0
}

# Validate domain name
validate_domain() {
    local domain=$1
    
    # Empty is allowed (optional field)
    if [ -z "$domain" ]; then
        return 0
    fi
    
    # Must not contain protocol
    if [[ "$domain" =~ ^https?:// ]]; then
        return 1
    fi
    
    # Basic domain format
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    
    return 1
}

# Validate PM2 app name
validate_pm2_app_name() {
    local name=$1
    
    if [ -z "$name" ]; then
        return 1
    fi
    
    # Alphanumeric, dash, underscore only
    if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    
    # Max length 64 chars
    if [ ${#name} -gt 64 ]; then
        return 1
    fi
    
    return 0
}

# Test SSH connection (optional)
test_ssh_connection() {
    local user=$1
    local host=$2
    local port=${3:-22}
    
    # Try connection with 5 second timeout
    if ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$port" "$user@$host" "exit" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Parse users.yml file
