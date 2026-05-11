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
    info "This wizard will guide you through basic server hardening."
    info "All changes are opt-in with clear rollback instructions."
    echo ""

    # Check SSH connection first
    info "Checking SSH connection..."
    if ! remote_exec "exit" &>/dev/null; then
        error "Cannot connect to $SSH_USER@$SSH_HOST:$SSH_PORT"
    fi
    success "SSH connection successful"
    echo ""

    # Check SSH service status
    local ssh_status
    ssh_status=$(check_ssh_service)
    if [[ "$ssh_status" == *"NOT_FOUND"* ]]; then
        warn "SSH service not detected on remote server"
    elif [[ "$ssh_status" == *"INACTIVE"* ]]; then
        warn "SSH service is installed but not running"
    fi
    echo ""

    local changes_made=0
    local backup_path=""
    local ssh_changes=0
    local summary=()

    # ==================== SSH Hardening ====================
    info "=== SSH Configuration Hardening ==="
    echo ""

    local current_port current_permit_root current_password_auth
    current_port=$(get_ssh_config "Port")
    current_permit_root=$(get_ssh_config "PermitRootLogin")
    current_password_auth=$(get_ssh_config "PasswordAuthentication")

    echo "Current SSH Configuration:"
    echo "  Port:                    ${current_port:-22 (default)}"
    echo "  PermitRootLogin:         ${current_permit_root:-yes (default)}"
    echo "  PasswordAuthentication:  ${current_password_auth:-yes (default)}"
    echo ""

    if prompt_yes_no "Configure SSH hardening?" "n"; then
        backup_path=$(backup_ssh_config)
        info "SSH config backed up to: $backup_path"
        echo ""

        # Change SSH port
        if prompt_yes_no "Change SSH port from ${current_port:-22}?" "n"; then
            echo ""
            echo "  1) 2222 (common alternative)"
            echo "  2) 1022 (registered alternative)"
            echo "  3) Custom port"
            echo ""
            read -rp "Select option [1-3]: " port_choice

            local new_port=""
            case "$port_choice" in
                1) new_port="2222" ;;
                2) new_port="1022" ;;
                3)
                    read -rp "Enter port (1024-65535): " new_port
                    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
                        warn "Invalid port. Skipping."
                        new_port=""
                    fi
                    ;;
                *) warn "Invalid choice. Skipping port change." ;;
            esac

            if [ -n "$new_port" ]; then
                local port_in_use
                port_in_use=$(remote_exec "ss -tlnp 2>/dev/null | grep -c ':${new_port} ' || true")
                if [ "${port_in_use:-0}" -gt 0 ]; then
                    warn "Port $new_port already in use. Skipping."
                    new_port=""
                fi
            fi

            if [ -n "$new_port" ]; then
                echo ""
                warn "After this change connect with: ssh -p $new_port $SSH_USER@$SSH_HOST"
                echo "Rollback: set 'Port $new_port' back to 'Port 22' in /etc/ssh/sshd_config"
                echo ""
                if prompt_yes_no "Proceed with port change to $new_port?" "n"; then
                    apply_ssh_config "Port" "$new_port"
                    SSH_PORT="$new_port"
                    sed -i "s/^SSH_PORT=.*/SSH_PORT=${new_port}/" shipnode.conf 2>/dev/null || true
                    ((ssh_changes++))
                    summary+=("SSH port changed to $new_port")
                fi
            fi
        fi

        # Disable root login
        if prompt_yes_no "Disable root login via SSH?" "n"; then
            echo "Rollback: set 'PermitRootLogin no' back to 'yes' in /etc/ssh/sshd_config"
            if prompt_yes_no "Proceed?" "n"; then
                apply_ssh_config "PermitRootLogin" "no"
                ((ssh_changes++))
                summary+=("Root login disabled")
            fi
        fi

        # Disable password authentication
        if prompt_yes_no "Disable password authentication (key-based only)?" "n"; then
            warn "Ensure SSH key access is configured before proceeding!"
            echo "Rollback: set 'PasswordAuthentication no' back to 'yes' in /etc/ssh/sshd_config"
            if prompt_yes_no "Proceed? (you must have SSH key access)" "n"; then
                apply_ssh_config "PasswordAuthentication" "no"
                ((ssh_changes++))
                summary+=("Password authentication disabled")
            fi
        fi

        if [ "$ssh_changes" -gt 0 ]; then
            # If port changed and UFW is active, open new port BEFORE restarting SSH
            if [ -n "${new_port:-}" ]; then
                local ufw_check
                ufw_check=$(remote_exec "command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -c 'Status: active' || echo 0")
                if [ "${ufw_check:-0}" -gt 0 ]; then
                    info "Opening port $new_port in UFW before restarting SSH..."
                    remote_exec "sudo ufw allow ${new_port}/tcp" &>/dev/null || true
                fi
            fi
            echo ""
            info "Restarting SSH service..."
            restart_ssh_service
            success "SSH service restarted"
            ((changes_made += ssh_changes))
        fi
    fi
    echo ""

    # ==================== Firewall Configuration ====================
    info "=== Firewall Configuration (UFW) ==="
    echo ""

    local ufw_status
    ufw_status=$(check_ufw)
    if [[ "$ufw_status" == "UFW_NOT_INSTALLED" ]]; then
        info "UFW is not installed."
        if prompt_yes_no "Install UFW?" "y"; then
            info "Installing UFW..."
            install_ufw
            success "UFW installed"
            summary+=("UFW installed")
        fi
    else
        echo "Current UFW status:"
        echo "$ufw_status"
    fi
    echo ""

    ufw_status=$(check_ufw)
    if [[ "$ufw_status" != "UFW_NOT_INSTALLED" ]]; then
        echo "Rules to apply: SSH (${SSH_PORT:-22}), HTTP (80), HTTPS (443) — deny everything else"
        echo "Rollback: sudo ufw disable"
        if prompt_yes_no "Configure UFW rules?" "y"; then
            apply_firewall_rules "${SSH_PORT:-22}"
            ((changes_made++))
            summary+=("UFW configured: SSH/HTTP/HTTPS allowed, all else denied")
            success "Firewall configured"
            echo ""
            check_ufw
        fi
    fi
    echo ""

    # ==================== Fail2ban Configuration ====================
    info "=== Fail2ban (Intrusion Prevention) ==="
    echo ""

    local fail2ban_status
    fail2ban_status=$(check_fail2ban)
    case "$fail2ban_status" in
        "ACTIVE")
            success "Fail2ban already installed and active"
            ;;
        "INSTALLED_INACTIVE")
            warn "Fail2ban installed but not running"
            if prompt_yes_no "Start and enable fail2ban?" "y"; then
                remote_exec "sudo systemctl start fail2ban && sudo systemctl enable fail2ban"
                success "Fail2ban started and enabled"
                ((changes_made++))
                summary+=("Fail2ban started and enabled")
            fi
            ;;
        "NOT_INSTALLED")
            info "Fail2ban not installed."
            echo "Monitors logs and bans IPs after repeated failed SSH attempts."
            echo "Config: 5 retries / 10 min window / 1 hour ban"
            echo "Rollback: sudo systemctl stop fail2ban && sudo systemctl disable fail2ban"
            if prompt_yes_no "Install and configure fail2ban?" "n"; then
                info "Installing fail2ban..."
                install_configure_fail2ban
                success "Fail2ban installed and configured"
                ((changes_made++))
                summary+=("Fail2ban installed (5 retries / 10 min / 1 hr ban)")
            fi
            ;;
    esac
    echo ""

    # ==================== Summary ====================
    info "=== Security Hardening Summary ==="
    echo ""

    if [ ${#summary[@]} -eq 0 ]; then
        warn "No changes made. Server configuration unchanged."
    else
        success "Changes applied: ${#summary[@]}"
        echo ""
        for item in "${summary[@]}"; do
            echo "  ✓ $item"
        done
        echo ""

        [ -n "$backup_path" ] && info "SSH config backup: $backup_path"

        echo ""
        echo "Reminders:"
        echo "  - Test SSH connection before closing this session"
        echo "  - Review firewall:  sudo ufw status"
        echo "  - Check fail2ban:   sudo fail2ban-client status"
        echo ""

        info "Testing SSH connection..."
        if remote_exec "exit" &>/dev/null; then
            success "SSH connection verified"
        else
            warn "SSH connection test failed — verify settings before disconnecting!"
        fi
    fi

    echo ""
    success "Hardening complete!"
}
