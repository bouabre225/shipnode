# Security

Server hardening and security best practices.

## Quick Hardening

Run the hardening wizard:

```bash
shipnode harden
```

This interactive wizard helps you:

### SSH Hardening

- **Disable password authentication** - Use SSH keys only
- **Disable root login** - Create a sudo user instead
- **Change SSH port** - Move from default port 22
- **Allowlist users** - Only specific users can SSH in

### Firewall (UFW)

- Enable UFW firewall
- Allow SSH (your port)
- Allow HTTP (80)
- Allow HTTPS (443)
- Deny all other incoming

### Fail2ban

Install fail2ban to block brute force attackers:
- Block after 5 failed attempts
- Ban for 10 minutes
- Monitor SSH logs

## Security Audit

Check your server's security:

```bash
shipnode doctor --security
```

This checks:
- SSH configuration
- Firewall status
- Fail2ban installation
- File permissions

## SSH Key Setup

1. **Generate a key** (on your local machine):
   ```bash
   ssh-keygen -t ed25519 -C "your@email.com"
   ```

2. **Add to server**:
   ```bash
   ssh-copy-id user@your-server
   ```

3. **Test connection**:
   ```bash
   ssh user@your-server
   ```

4. **Disable password auth** (after confirming key works):
   ```bash
   # In /etc/ssh/sshd_config
   PasswordAuthentication no
   systemctl restart sshd
   ```

## Firewall Rules

### Basic Setup

```bash
# Allow SSH (port 22, or your custom port)
ufw allow 22

# Allow HTTP/HTTPS
ufw allow 80
ufw allow 443

# Enable firewall
ufw enable
```

### With Custom SSH Port

```bash
ufw allow 2222/tcp  # your custom SSH port
ufw delete allow 22  # remove default
```

## fail2ban Configuration

ShipNode's fail2ban configuration:

```ini
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
```

## User Provisioning

Manage deployment users with `users.yml`:

```yaml
users:
  - username: alice
    email: alice@example.com
    authorized_key: "ssh-ed25519 AAAAC3... alice@laptop"
    sudo: false

  - username: bob
    email: bob@example.com
    authorized_key: "ssh-ed25519 AAAAC3... bob@laptop"
    sudo: true
```

Sync users:

```bash
shipnode user sync
```

## Security Checklist

- [ ] SSH key authentication enabled
- [ ] Root login disabled
- [ ] SSH port changed (optional)
- [ ] UFW firewall enabled
- [ ] fail2ban installed
- [ ] Regular security updates: `apt update && apt upgrade`
- [ ] Backups configured
- [ ] .env file not in version control
- [ ] Secrets not committed to git
