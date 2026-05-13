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

## One-Off Remote Commands

Run commands on the server in the deployed app context:

```bash
shipnode run "npm run db:seed"
shipnode run "npx prisma migrate deploy"
shipnode run "node -v"
```

Interactive commands can request a TTY:

```bash
shipnode run bash --tty
```

`shipnode run` loads `shipnode.conf`, enters `$REMOTE_PATH/current`, sources `$REMOTE_PATH/shared/.env` when present, and executes the command with the configured project Node.js runtime (`NODE_VERSION`) via mise when available.

Profiles and custom config files work with `run` too:

```bash
shipnode run "node -v" --profile staging
shipnode run "npm run db:seed" --config shipnode.production.conf
```

Before executing the user command, ShipNode repairs execute permissions only for package-declared binaries in `node_modules` (`node_modules/.bin` targets and `package.json` `bin` entries). This prevents `Permission denied` errors from broken package binary permissions without broadly chmodding the app tree.

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

- `SHIPNODE_SSH_KEY`
- `SHIPNODE_SSH_HOST`
- `SHIPNODE_SSH_USER`
- `SHIPNODE_SSH_PORT`
- `SHIPNODE_KNOWN_HOSTS` (recommended)

Typical deploy step:

```yaml
- run: curl -fsSL https://github.com/devalade/shipnode/releases/latest/download/shipnode-installer.sh | bash
- run: shipnode --config shipnode.ci.conf deploy
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
