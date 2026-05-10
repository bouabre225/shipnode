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
        sudo sed -i "s/^#\(${key}[[:space:]]\)/\1/" /etc/ssh/sshd_config
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
        if ! \$SUDO ufw status | grep -qE "^\[?${ssh_port}\]"; then
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
            if systemctl is-active fail2ban &> /dev/null 2>&1; then
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
        local log_path="/var/log/auth.log"
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
    ensure_gum_for_ui

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
    local ssh_status=$(check_ssh_service)
    if [[ "$ssh_status" == *"NOT_FOUND"* ]]; then
        warn "SSH service not detected on remote server"
    elif [[ "$ssh_status" == *"INACTIVE"* ]]; then
        warn "SSH service is installed but not running"
    fi
    echo ""

    local changes_made=0
    local backup_path=""

    # ==================== SSH Hardening ====================
    info "=== SSH Configuration Hardening ==="
    echo ""

    # Show current SSH settings
    local current_port=$(get_ssh_config "Port")
    local current_permit_root=$(get_ssh_config "PermitRootLogin")
    local current_password_auth=$(get_ssh_config "PasswordAuthentication")

    echo "Current SSH Configuration:"
    echo "  Port: ${current_port:-22} (default if not set)"
    echo "  PermitRootLogin: ${current_permit_root:-yes} (default if not set)"
    echo "  PasswordAuthentication: ${current_password_auth:-yes} (default if not set)"
    echo ""

    # Ask if user wants to harden SSH
    echo ""
    if gum_confirm "Would you like to configure SSH hardening?" "n"; then
        backup_path=$(backup_ssh_config)
        info "SSH config backed up to: $backup_path"
        echo ""

        # Change SSH port
        if gum_confirm "Change SSH port from default (22)?" "n"; then
            echo ""
            info "Available ports:"
            echo "  1) 2222 (commonly used alternative)"
            echo "  2) 1022 (registered alternative)"
            echo "  3) Custom port"
            echo ""

            local port_choice=$(gum_choose "Select new SSH port:" "2222" "1022" "Custom port")

            local new_port=""
            case "$port_choice" in
                "2222")
                    new_port="2222"
                    ;;
                "1022")
                    new_port="1022"
                    ;;
                "Custom port")
                    new_port=$(gum_input "Enter custom SSH port (1024-65535):" "")
                    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
                        warn "Invalid port number. Skipping port change."
                        new_port=""
                    fi
                    ;;
            esac

            if [ -n "$new_port" ]; then
                # Check if port is already in use on the remote server
                local port_in_use=$(remote_exec "ss -tlnp 2>/dev/null | grep -c ':${new_port} ' || true")
                if [ "${port_in_use:-0}" -gt 0 ]; then
                    warn "Port $new_port is already in use on the remote server. Skipping port change."
                    new_port=""
                fi
            fi

            if [ -n "$new_port" ]; then
                echo ""
                warn "Changing SSH port to $new_port"
                echo ""
                echo "⚠ IMPORTANT: Make sure to update your firewall and SSH client configuration!"
                echo "   After this change, connect using: ssh -p $new_port $SSH_USER@$SSH_HOST"
                echo ""
                echo "Rollback: Edit /etc/ssh/sshd_config and change 'Port $new_port' to 'Port 22'"
                echo ""

                if gum_confirm "Proceed with changing SSH port to $new_port?" "n"; then
                    apply_ssh_config "Port" "$new_port"
                    SSH_PORT="$new_port"
                    # Persist SSH_PORT to shipnode.conf on the server
                    remote_exec "sed -i 's/^SSH_PORT=.*/SSH_PORT=${new_port}/' ${REMOTE_PATH}/shipnode.conf" 2>/dev/null || true
                    ((changes_made++))
                    success "SSH port configured: $new_port"
                    echo ""
                else
                    info "SSH port change skipped."
                    echo ""
                fi
            fi
        fi

        # Disable root login
        if gum_confirm "Disable root login via SSH?" "n"; then
            echo ""
            warn "This will prevent direct root SSH access."
            echo "Rollback: Edit /etc/ssh/sshd_config and change 'PermitRootLogin no' to 'PermitRootLogin yes'"
            echo ""

            if gum_confirm "Proceed with disabling root login?" "n"; then
                apply_ssh_config "PermitRootLogin" "no"
                ((changes_made++))
                success "Root login disabled via SSH"
                echo ""
            else
                info "Root login change skipped."
                echo ""
            fi
        fi

        # Disable password authentication
        if gum_confirm "Disable password authentication (key-based auth only)?" "n"; then
            echo ""
            warn "This will disable password authentication."
            echo "⚠ WARNING: Make sure you have SSH key access configured before proceeding!"
            echo ""
            echo "Rollback: Edit /etc/ssh/sshd_config and change 'PasswordAuthentication no' to 'PasswordAuthentication yes'"
            echo ""

            if gum_confirm "Are you sure? You must have SSH key access!" "n"; then
                apply_ssh_config "PasswordAuthentication" "no"
                ((changes_made++))
                success "Password authentication disabled"
                echo ""
            else
                info "Password authentication change skipped."
                echo ""
            fi
        fi

        # Restart SSH if changes were made
        if [ $changes_made -gt 0 ]; then
            echo ""
            info "Restarting SSH service to apply changes..."
            restart_ssh_service
            success "SSH service restarted"
            echo ""
        fi
    else
        info "SSH hardening skipped."
        echo ""
    fi

    # ==================== Firewall Configuration ====================
    info "=== Firewall Configuration (UFW) ==="
    echo ""

    local ufw_status=$(check_ufw)
    if [[ "$ufw_status" == "UFW_NOT_INSTALLED" ]]; then
        info "UFW (Uncomplicated Firewall) is not installed."
        if gum_confirm "Install and configure UFW firewall?" "y"; then
            echo ""
            info "Installing UFW..."
            install_ufw
            success "UFW installed"
            echo ""
        else
            warn "Firewall configuration skipped."
            echo ""
        fi
    else
        echo "Current UFW status:"
        echo "$ufw_status"
        echo ""
    fi

    # Check UFW again after potential install
    ufw_status=$(check_ufw)
    if [[ "$ufw_status" != "UFW_NOT_INSTALLED" ]]; then
        if gum_confirm "Configure UFW firewall rules (SSH, HTTP, HTTPS)?" "y"; then
            echo ""
            echo "Firewall rules to be applied:"
            echo "  ✓ Allow SSH (port ${SSH_PORT:-22})"
            echo "  ✓ Allow HTTP (port 80)"
            echo "  ✓ Allow HTTPS (port 443)"
            echo "  ✗ Deny all other incoming traffic"
            echo ""
            echo "Rollback: Run 'sudo ufw disable' or 'sudo ufw reset'"
            echo ""

            if gum_confirm "Proceed with firewall configuration?" "y"; then
                apply_firewall_rules "${SSH_PORT:-22}"
                ((changes_made++))
                success "Firewall configured successfully"
                echo ""
                info "Current status:"
                check_ufw
                echo ""
            else
                info "Firewall configuration skipped."
                echo ""
            fi
        else
            info "Firewall configuration skipped."
            echo ""
        fi
    fi

    # ==================== Fail2ban Configuration ====================
    info "=== Fail2ban (Intrusion Prevention) ==="
    echo ""

    local fail2ban_status=$(check_fail2ban)
    case "$fail2ban_status" in
        "ACTIVE")
            info "Fail2ban is already installed and active"
            echo ""
            ;;
        "INSTALLED_INACTIVE")
            warn "Fail2ban is installed but not running"
            if gum_confirm "Start and enable fail2ban?" "y"; then
                remote_exec "sudo systemctl start fail2ban && sudo systemctl enable fail2ban"
                success "Fail2ban started and enabled"
                ((changes_made++))
            fi
            echo ""
            ;;
        "NOT_INSTALLED")
            info "Fail2ban is not installed."
            echo "Fail2ban monitors log files and bans IPs that show malicious signs (e.g., multiple failed SSH attempts)."
            echo ""

            if gum_confirm "Install and configure fail2ban?" "n"; then
                echo ""
                info "Installing fail2ban..."
                install_configure_fail2ban
                success "Fail2ban installed and configured"
                echo ""
                echo "Configuration:"
                echo "  - Max retry: 5 attempts"
                echo "  - Find time: 10 minutes"
                echo "  - Ban time: 1 hour"
                echo ""
                echo "Rollback: sudo systemctl stop fail2ban && sudo systemctl disable fail2ban"
                echo "         Then remove the package using your system's package manager"
                echo ""
                ((changes_made++))
            else
                info "Fail2ban installation skipped."
                echo ""
            fi
            ;;
    esac

    # ==================== Summary ====================
    echo ""
    info "=== Security Hardening Summary ==="
    echo ""

    if [ $changes_made -eq 0 ]; then
        warn "No security changes were made."
        info "Server configuration remains unchanged."
    else
        success "Security hardening completed!"
        info "Total changes applied: $changes_made"
        echo ""

        if [ -n "$backup_path" ]; then
            info "SSH configuration backup: $backup_path"
        fi

        echo ""
        echo "Important reminders:"
        echo "  - Test your SSH connection before closing this session"
        echo "  - If you changed the SSH port, update your SSH client config"
        echo "  - Review firewall rules with: sudo ufw status"
        echo "  - Check fail2ban status with: sudo fail2ban-client status"
        echo ""

        # Test SSH connection
        info "Testing SSH connection..."
        if remote_exec "exit" &>/dev/null; then
            success "SSH connection verified"
        else
            warn "SSH connection test failed!"
            warn "Please verify your connection settings before disconnecting."
        fi
    fi

    echo ""
    success "Hardening complete!"
}
