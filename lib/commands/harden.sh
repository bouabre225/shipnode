#!/usr/bin/env bash
#
# ShipNode Harden - Server Security Hardening
# Apply basic security hardening with opt-in changes and clear rollback hints
#

# Check if SSH service is installed and running
check_ssh_service() {
    remote_exec bash << 'EOF'
        if command -v systemctl &> /dev/null; then
            if systemctl list-unit-files | grep -q ssh.service; then
                systemctl is-active ssh &> /dev/null && echo "SSH_ACTIVE" || echo "SSH_INACTIVE"
            elif systemctl list-unit-files | grep -q sshd.service; then
                systemctl is-active sshd &> /dev/null && echo "SSHD_ACTIVE" || echo "SSHD_INACTIVE"
            else
                echo "SSH_NOT_FOUND"
            fi
        else
            # Check with service command for older systems
            if service ssh status &> /dev/null || service sshd status &> /dev/null; then
                echo "SSH_ACTIVE"
            else
                echo "SSH_NOT_FOUND"
            fi
        fi
EOF
}

# Get current SSH configuration value
get_ssh_config() {
    local config_key="$1"
    remote_exec bash << EOF
        if [ -f /etc/ssh/sshd_config ]; then
            grep -E "^${config_key}[[:space:]]" /etc/ssh/sshd_config | awk '{print \$2}' | tail -1
        fi
EOF
}

# Backup SSH configuration before making changes
backup_ssh_config() {
    local backup_file="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    remote_exec bash << EOF
        sudo cp /etc/ssh/sshd_config "${backup_file}"
        echo "${backup_file}"
EOF
}

# Apply SSH configuration change
apply_ssh_config() {
    local key="$1"
    local value="$2"
    remote_exec bash << EOF
        # Uncomment if the key is commented out
        sudo sed -i "s/^#[[:space:]]*\(${key}[[:space:]]\)/\1/" /etc/ssh/sshd_config
        # Check if the configuration already exists
        if grep -qE "^${key}[[:space:]]" /etc/ssh/sshd_config; then
            # Update existing line
            sudo sed -i "s/^${key}[[:space:]].*/${key} ${value}/" /etc/ssh/sshd_config
        else
            # Add new line
            echo "${key} ${value}" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        fi
EOF
}

# Restart SSH service
restart_ssh_service() {
    remote_exec bash << 'EOF'
        if command -v systemctl &> /dev/null; then
            if systemctl list-unit-files | grep -q ssh.service; then
                sudo systemctl restart ssh
            elif systemctl list-unit-files | grep -q sshd.service; then
                sudo systemctl restart sshd
            fi
        else
            if service ssh status &> /dev/null 2>&1; then
                sudo service ssh restart
            elif service sshd status &> /dev/null 2>&1; then
                sudo service sshd restart
            fi
        fi
EOF
}

# Check UFW status
check_ufw() {
    remote_exec bash << 'EOF'
        if command -v ufw &> /dev/null; then
            ufw status numbered 2>&1 | head -30
        else
            echo "UFW_NOT_INSTALLED"
        fi
EOF
}

# Install UFW if not present (supports multiple package managers)
install_ufw() {
    remote_exec bash << 'EOF'
        set -e
        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        if command -v apt &> /dev/null; then
            $SUDO apt-get update
            $SUDO apt-get install -y ufw
        elif command -v dnf &> /dev/null; then
            $SUDO dnf install -y ufw
        elif command -v yum &> /dev/null; then
            $SUDO yum install -y ufw
        elif command -v apk &> /dev/null; then
            $SUDO apk add --no-cache ufw
        elif command -v pacman &> /dev/null; then
            $SUDO pacman -S --needed --noconfirm ufw
        else
            echo "ERROR: No supported package manager found (apt, dnf, yum, apk, pacman)"
            exit 1
        fi
EOF
}

# Apply firewall rules (non-destructive - preserves existing rules)
apply_firewall_rules() {
    local ssh_port="${1:-22}"
    remote_exec bash << EOF
        set -e
        SUDO=""
        if [ "\$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        # Back up existing rules if any
        if \$SUDO ufw status | grep -q "Status: active"; then
            \$SUDO ufw status numbered > /tmp/ufw-rules-backup-\$(date +%s).txt 2>/dev/null || true
        fi

        # Set default policies (only if not already set)
        \$SUDO ufw default deny incoming 2>/dev/null || true
        \$SUDO ufw default allow outgoing 2>/dev/null || true

        # Allow SSH (only if not already allowed)
        if ! \$SUDO ufw status | grep -qE "${ssh_port}/tcp"; then
            \$SUDO ufw allow ${ssh_port}/tcp
        fi

        # Allow HTTP and HTTPS (only if not already allowed)
        if ! \$SUDO ufw status | grep -q "80/tcp"; then
            \$SUDO ufw allow 80/tcp
        fi
        if ! \$SUDO ufw status | grep -q "443/tcp"; then
            \$SUDO ufw allow 443/tcp
        fi

        # Enable firewall
        echo "y" | \$SUDO ufw enable
EOF
}

# List non-root users with sudo access
check_sudo_users() {
    remote_exec bash << 'EOF'
        # Users in sudo or wheel group, excluding root
        users=""
        for group in sudo wheel; do
            if getent group "$group" &>/dev/null; then
                members=$(getent group "$group" | cut -d: -f4 | tr ',' '\n' | grep -v '^root$' | grep -v '^$')
                users=$(printf "%s\n%s" "$users" "$members")
            fi
        done
        # Also check sudoers for explicit user entries
        if [ -f /etc/sudoers ]; then
            explicit=$(grep -E '^[a-zA-Z][a-zA-Z0-9_-]+\s+ALL=' /etc/sudoers 2>/dev/null | awk '{print $1}' | grep -v '^root$')
            users=$(printf "%s\n%s" "$users" "$explicit")
        fi
        echo "$users" | sort -u | grep -v '^$' || true
EOF
}

# Check fail2ban status
check_fail2ban() {
    remote_exec bash << 'EOF'
        if command -v fail2ban-server &> /dev/null; then
            if systemctl is-active fail2ban &>/dev/null; then
                echo "ACTIVE"
            else
                echo "INSTALLED_INACTIVE"
            fi
        else
            echo "NOT_INSTALLED"
        fi
EOF
}

# Install and configure fail2ban (supports multiple package managers)
install_configure_fail2ban() {
    remote_exec bash << 'ENDSSH'
        set -e
        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        # Install fail2ban for the detected package manager
        if command -v apt &> /dev/null; then
            $SUDO apt-get update
            $SUDO apt-get install -y fail2ban
        elif command -v dnf &> /dev/null; then
            $SUDO dnf install -y fail2ban
        elif command -v yum &> /dev/null; then
            $SUDO yum install -y fail2ban
        elif command -v apk &> /dev/null; then
            $SUDO apk add --no-cache fail2ban
        elif command -v pacman &> /dev/null; then
            $SUDO pacman -S --needed --noconfirm fail2ban
        else
            echo "ERROR: No supported package manager found"
            exit 1
        fi

        # Determine log path based on distro
        log_path="/var/log/auth.log"
        if [ -f "/var/log/secure" ]; then
            log_path="/var/log/secure"
        fi

        # Create basic SSH jail configuration
        cat << 'JAILCONF' | $SUDO tee /etc/fail2ban/jail.local > /dev/null
[DEFAULT]
# Ban IP after 5 failed attempts within 10 minutes
maxretry = 5
findtime = 600
# Ban for 1 hour
bantime = 3600

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = LOGPATH
maxretry = 5
JAILCONF

        # Replace placeholder with actual log path
        $SUDO sed -i "s|LOGPATH|${log_path}|g" /etc/fail2ban/jail.local

        # Enable and start fail2ban
        $SUDO systemctl enable fail2ban 2>/dev/null || true
        $SUDO systemctl restart fail2ban
ENDSSH
}

# Main harden command
cmd_harden() {
    load_config

    info "ShipNode Security Hardening"
    echo ""

    info "Checking SSH connection..."
    if ! remote_exec "exit" &>/dev/null; then
        error "Cannot connect to $SSH_USER@$SSH_HOST:$SSH_PORT"
    fi
    success "SSH connection successful"
    echo ""

    local changes_made=0
    local backup_path=""
    local ssh_changes=0
    local summary=()

    # ==================== SSH ====================
    info "=== SSH ==="
    echo ""

    local current_permit_root current_password_auth
    current_permit_root=$(get_ssh_config "PermitRootLogin")
    current_password_auth=$(get_ssh_config "PasswordAuthentication")

    echo "  PermitRootLogin:         ${current_permit_root:-yes (default)}"
    echo "  PasswordAuthentication:  ${current_password_auth:-yes (default)}"
    echo ""

    if prompt_yes_no "Harden SSH?" "n"; then
        backup_path=$(backup_ssh_config)
        info "SSH config backed up to: $backup_path"
        echo ""

        local sudo_users
        sudo_users=$(check_sudo_users)
        if [ -z "$sudo_users" ]; then
            warn "No non-root sudo users found — skipping root login option."
            warn "Create a sudo user first: shipnode user sync"
        else
            info "Non-root sudo users found: $(echo "$sudo_users" | tr '\n' ' ')"
            if prompt_yes_no "Disable root login?" "n"; then
                apply_ssh_config "PermitRootLogin" "no"
                ((ssh_changes++))
                summary+=("Root login disabled")
            fi
        fi

        if prompt_yes_no "Disable password auth (key-based only)?" "n"; then
            warn "Ensure you have SSH key access before proceeding!"
            if prompt_yes_no "Confirm?" "n"; then
                apply_ssh_config "PasswordAuthentication" "no"
                ((ssh_changes++))
                summary+=("Password authentication disabled")
            fi
        fi

        if [ "$ssh_changes" -gt 0 ]; then
            info "Restarting SSH..."
            restart_ssh_service
            success "SSH restarted"
            ((changes_made += ssh_changes))
        fi
    fi
    echo ""

    # ==================== Firewall ====================
    info "=== Firewall (UFW) ==="
    echo ""

    local ufw_status
    ufw_status=$(check_ufw)
    if [[ "$ufw_status" == "UFW_NOT_INSTALLED" ]]; then
        info "UFW not installed."
        if prompt_yes_no "Install UFW?" "y"; then
            install_ufw
            success "UFW installed"
            summary+=("UFW installed")
        fi
    else
        echo "$ufw_status"
    fi
    echo ""

    ufw_status=$(check_ufw)
    if [[ "$ufw_status" != "UFW_NOT_INSTALLED" ]]; then
        echo "Will allow: SSH (${SSH_PORT:-22}), HTTP (80), HTTPS (443) — deny all else"
        if prompt_yes_no "Configure UFW?" "y"; then
            apply_firewall_rules "${SSH_PORT:-22}"
            ((changes_made++))
            summary+=("UFW configured")
            success "Firewall configured"
        fi
    fi
    echo ""

    # ==================== Fail2ban ====================
    info "=== Fail2ban ==="
    echo ""

    local fail2ban_status
    fail2ban_status=$(check_fail2ban)
    case "$fail2ban_status" in
        "ACTIVE")
            success "Fail2ban already active"
            ;;
        "INSTALLED_INACTIVE")
            warn "Fail2ban installed but not running"
            if prompt_yes_no "Start fail2ban?" "y"; then
                remote_exec "sudo systemctl start fail2ban && sudo systemctl enable fail2ban"
                success "Fail2ban started"
                ((changes_made++))
                summary+=("Fail2ban started")
            fi
            ;;
        "NOT_INSTALLED")
            info "Fail2ban not installed."
            echo "Bans IPs after 5 failed SSH attempts within 10 min for 1 hour."
            if prompt_yes_no "Install fail2ban?" "n"; then
                install_configure_fail2ban
                success "Fail2ban installed"
                ((changes_made++))
                summary+=("Fail2ban installed")
            fi
            ;;
    esac
    echo ""

    # ==================== Summary ====================
    if [ ${#summary[@]} -eq 0 ]; then
        warn "No changes made."
    else
        success "Done — ${#summary[@]} change(s) applied:"
        for item in "${summary[@]}"; do
            echo "  ✓ $item"
        done
        [ -n "$backup_path" ] && echo "" && info "SSH backup: $backup_path"
    fi
    echo ""
}
