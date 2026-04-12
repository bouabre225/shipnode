# Commands Reference

All ShipNode commands with descriptions.

## Setup Commands

| Command | Description |
|---------|-------------|
| `shipnode init` | Initialize project configuration (interactive) |
| `shipnode init --non-interactive` | Initialize without prompts (for CI) |
| `shipnode init --template <name>` | Use a framework preset |
| `shipnode init --print` | Print config without writing |
| `shipnode setup` | Install Node.js, PM2, Caddy on server |

## Deploy Commands

| Command | Description |
|---------|-------------|
| `shipnode deploy` | Deploy your app |
| `shipnode deploy --skip-build` | Skip build step |
| `shipnode deploy --dry-run` | Preview without deploying |
| `shipnode deploy --config <file>` | Use specific config file |
| `shipnode deploy --profile <name>` | Use `shipnode.<name>.conf` |

## Monitor Commands

| Command | Description |
|---------|-------------|
| `shipnode status` | Rich status dashboard |
| `shipnode logs` | Stream live PM2 logs |
| `shipnode metrics` | Real-time CPU/memory monitor |
| `shipnode releases` | List all releases |

## Manage Commands

| Command | Description |
|---------|-------------|
| `shipnode rollback` | Rollback to previous release |
| `shipnode rollback <n>` | Rollback n releases |
| `shipnode rollback <timestamp>` | Rollback to specific release |
| `shipnode restart` | Restart app gracefully |
| `shipnode stop` | Stop app |
| `shipnode unlock` | Clear stuck deployment lock |

## Customize Commands

| Command | Description |
|---------|-------------|
| `shipnode eject` | Eject PM2 + Caddy templates |
| `shipnode eject pm2` | Eject only PM2 template |
| `shipnode eject caddy` | Eject only Caddy template |
| `shipnode config` | Show resolved config values |
| `shipnode config validate` | Validate config without deploying |

## Environment Commands

| Command | Description |
|---------|-------------|
| `shipnode env` | Upload .env to server |
| `shipnode env pull` | Download .env from server |
| `shipnode env list` | List environment variables |

## User Commands

| Command | Description |
|---------|-------------|
| `shipnode user sync` | Sync users from users.yml |
| `shipnode user list` | List provisioned users |
| `shipnode user remove <user>` | Revoke user access |
| `shipnode mkpasswd` | Generate password hash |

## CI/CD Commands

| Command | Description |
|---------|-------------|
| `shipnode ci github` | Generate GitHub Actions workflow |
| `shipnode ci env-sync` | Sync config to GitHub secrets |
| `shipnode ci env-sync --all` | Sync config + .env |

## Diagnostic Commands

| Command | Description |
|---------|-------------|
| `shipnode doctor` | Pre-flight checks |
| `shipnode doctor --security` | Security audit |
| `shipnode harden` | Server hardening wizard |
| `shipnode upgrade` | Upgrade ShipNode |

## Other Commands

| Command | Description |
|---------|-------------|
| `shipnode help` | Show help message |
| `shipnode version` | Show version |
| `shipnode migrate` | Migrate to release structure |

## Global Flags

| Flag | Description |
|------|-------------|
| `--help, -h` | Show help |
| `--version, -v` | Show version |
| `--quiet, -q` | Suppress output |
| `--debug` | Enable debug mode |
