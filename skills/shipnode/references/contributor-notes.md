# Contributor Notes

Use this reference only when the user wants to modify ShipNode itself.

## Codebase Shape

The `shipnode` entry point sources core modules, command modules, then calls `main()` from `lib/commands/main.sh`.

Core modules:

- `lib/core.sh`: globals, logging, OS detection, Gum install, template rendering.
- `lib/release.sh`: release management, locks, health checks, rollback helpers.
- `lib/database.sh`: PostgreSQL, MySQL, SQLite, and Redis setup.
- `lib/users.sh`: user provisioning.
- `lib/framework.sh`: framework detection.
- `lib/validation.sh`: input validation.
- `lib/prompts.sh`: Gum UI wrappers with shell fallbacks.
- `lib/pkg-manager.sh`: npm/yarn/pnpm/bun detection.
- `lib/templates.sh`: framework presets.

Commands live in `lib/commands/` and use `cmd_<name>()`.

## Adding Commands

1. Add `lib/commands/<command>.sh`.
2. Register it in `lib/commands/main.sh`.
3. Update `lib/commands/help.sh`.
4. Update README/docs for user-facing behavior.
5. Run `bash -n` on touched files and `make build` when installer output changes.

## Validation

```bash
bash -n <file>
shellcheck <file>
make build
make test
make test-integration-local
make test-integration
```

Modules should define functions only and avoid source-time side effects.
