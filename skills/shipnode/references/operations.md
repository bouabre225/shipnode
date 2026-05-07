# Operations

## Release Layout

ShipNode uses timestamped releases:

```text
/var/www/myapp/
├── releases/
│   ├── 20250129_120000/
│   └── 20250129_130000/
├── current -> releases/20250129_130000/
├── shared/
│   └── .env
└── .deploy.lock
```

`current` is switched atomically. `shared/.env` persists across releases and is linked into each release.

## Status, Logs, and Metrics

```bash
shipnode status
shipnode logs
shipnode metrics
shipnode releases
```

For a failing production app, check logs before restarting when possible.

## Rollback

Rollback to the previous release:

```bash
shipnode rollback
```

Rollback by count or timestamp:

```bash
shipnode rollback 2
shipnode rollback 20250129_120000
```

Rollback switches `current` and reloads services. It does not rebuild or redeploy.

## Environment Variables

Do not commit real `.env` files. Keep `.env.example` with placeholders.

Upload or update secrets:

```bash
shipnode env
shipnode restart
```

Manual upload:

```bash
scp .env root@your-server:/var/www/myapp/shared/.env
```

Pre/post deploy hooks can use `$SHARED_ENV_PATH`.

## Multi-Environment Profiles

Use separate configs:

```text
shipnode.conf
shipnode.staging.conf
shipnode.production.conf
```

Deploy with:

```bash
shipnode deploy --profile staging
shipnode deploy --profile production
```

Each environment should have its own server path, domain, and `.env`.

## CI/CD

Generate a GitHub Actions workflow:

```bash
shipnode ci github
```

Use repository secrets for SSH:

- `SSH_PRIVATE_KEY`
- `SSH_HOST`
- `SSH_USER`

Typical deploy step:

```yaml
- uses: devalade/shipnode-action@latest
- run: shipnode deploy --profile production
  env:
    SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
    SSH_HOST: ${{ secrets.SSH_HOST }}
    SSH_USER: ${{ secrets.SSH_USER }}
```

Sync config/secrets when appropriate:

```bash
shipnode ci env-sync
shipnode ci env-sync --all
```

## Security Hardening

Run:

```bash
shipnode harden
shipnode doctor --security
```

Hardening can:

- Disable password authentication.
- Disable root login.
- Change SSH port.
- Enable UFW.
- Install fail2ban.

Warn users before applying hardening changes, especially if they have not tested SSH key login or opened the new SSH port in the firewall.

## User Provisioning

Manage server users with `users.yml`:

```yaml
users:
  - username: alice
    email: alice@example.com
    authorized_key: "ssh-ed25519 AAAAC3... alice@laptop"
    sudo: false
```

Sync:

```bash
shipnode user sync
shipnode user list
shipnode user remove alice
```
