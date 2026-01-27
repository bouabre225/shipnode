init_users_yaml() {
    local users_data=()

    info "Add deployment users to users.yml"
    echo ""

    while true; do
        local username email auth_method ssh_key password sudo_access

        # Prompt for username
        while true; do
            read -p "Username: " username
            if [ -z "$username" ]; then
                warn "Username cannot be empty"
                continue
            fi
            if ! validate_username "$username"; then
                warn "Invalid username (alphanumeric, dash, underscore, max 32 chars)"
                continue
            fi
            break
        done

        # Prompt for email
        while true; do
            read -p "Email: " email
            if [ -z "$email" ]; then
                warn "Email cannot be empty"
                continue
            fi
            if ! validate_email "$email"; then
                warn "Invalid email address"
                continue
            fi
            break
        done

        # Prompt for auth method
        echo ""
        echo "Authentication method:"
        echo "  1) SSH key"
        echo "  2) Password"
        read -p "Choose (1-2): " -n 1 auth_choice
        echo ""
        echo ""

        case "$auth_choice" in
            1)
                auth_method="ssh"
                # Prompt for SSH public key
                while true; do
                    read -p "SSH public key: " ssh_key
                    if [ -z "$ssh_key" ]; then
                        warn "SSH key cannot be empty"
                        continue
                    fi
                    if ! validate_ssh_key "$ssh_key"; then
                        warn "Invalid SSH key format"
                        continue
                    fi
                    break
                done
                ;;
            2)
                auth_method="password"
                # Prompt for password with confirmation
                while true; do
                    read -sp "Password: " password
                    echo
                    if [ -z "$password" ]; then
                        warn "Password cannot be empty"
                        continue
                    fi
                    read -sp "Confirm password: " password2
                    echo
                    if [ "$password" != "$password2" ]; then
                        warn "Passwords do not match"
                        continue
                    fi
                    break
                done
                ;;
            *)
                warn "Invalid choice, defaulting to SSH key"
                auth_method="ssh"
                while true; do
                    read -p "SSH public key: " ssh_key
                    if [ -z "$ssh_key" ]; then
                        warn "SSH key cannot be empty"
                        continue
                    fi
                    if ! validate_ssh_key "$ssh_key"; then
                        warn "Invalid SSH key format"
                        continue
                    fi
                    break
                done
                ;;
        esac

        # Prompt for sudo access
        sudo_access="false"
        if prompt_yes_no "Grant sudo access?"; then
            sudo_access="true"
        fi

        # Store user data
        users_data+=("$username|$email|$auth_method|$ssh_key|$password|$sudo_access")

        echo ""
        if ! prompt_yes_no "Add another user?"; then
            break
        fi
        echo ""
    done

    # Generate users.yml
    cat > users.yml << 'EOF'
# ShipNode User Configuration
# Sync users to server: shipnode user sync

users:
EOF

    for user_entry in "${users_data[@]}"; do
        IFS='|' read -r username email auth_method ssh_key password sudo_access <<< "$user_entry"

        echo "  - username: $username" >> users.yml
        echo "    email: $email" >> users.yml

        if [ "$auth_method" = "ssh" ]; then
            echo "    authorized_key: \"$ssh_key\"" >> users.yml
        else
            # Generate password hash
            local hash=$(generate_password_hash "$password")
            echo "    password: \"$hash\"" >> users.yml
        fi

        if [ "$sudo_access" = "true" ]; then
            echo "    sudo: true" >> users.yml
        fi

        echo "" >> users.yml
    done

    # Add footer comment
    echo "# Generate password hashes: shipnode mkpasswd" >> users.yml

    success "Created users.yml with ${#users_data[@]} user(s)"
    info "Review users.yml and run: shipnode user sync"
}

# ============================================================================
