# Environment Variables

Manage your `.env` file securely with ShipNode.

## Security First

ShipNode **never** syncs your `.env` file automatically. This prevents:
- Accidental exposure of secrets in version control
- Syncing development secrets to production
- Unintended overwrites

## Upload .env to Server

```bash
# Method 1: scp directly
scp .env root@your-server:/var/www/myapp/shared/.env

# Method 2: Using ShipNode
shipnode env
```

The `.env` file lives in `shared/` and is symlinked into each release.

## Directory Structure

```
/var/www/myapp/
├── current -> releases/20260408143022/
├── releases/
│   └── 20260408143022/
│       └── .env -> ../../shared/.env  ← symlink
└── shared/
    └── .env                              ← persistent
```

## Update .env

```bash
# Edit locally, then upload
shipnode env

# Or manually
scp .env root@your-server:/var/www/myapp/shared/.env

# Restart app to pick up changes
shipnode restart
```

## Multiple Environments

Each environment should have its own `.env`:

```bash
# Production
shipnode deploy --profile production
scp .env.production root@server:/var/www/myapp/shared/.env

# Staging
shipnode deploy --profile staging
scp .env.staging root@staging:/var/www/staging/shared/.env
```

## Hooks and .env

Pre/post deploy hooks have access to .env via `$SHARED_ENV_PATH`:

```bash
#!/bin/bash
source "$SHARED_ENV_PATH"

# Now you can use $DATABASE_URL, $API_KEY, etc.
npx prisma migrate deploy
```

## .env in Version Control

Keep a `.env.example` (no real values):

```bash
# .env.example (safe to commit)
DATABASE_URL=postgresql://user:pass@localhost:5432/mydb
API_KEY=your-api-key-here
```

Add `.env` to `.gitignore`:

```
# .gitignore
.env
.env.*
!.env.example
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| App can't find env vars | Check symlink: `ls -la releases/*/.env` |
| Wrong values | Verify `shared/.env` on server |
| Changes not applied | Restart: `shipnode restart` |

## Auto-Load in Shell

If you need .env loaded locally for development:

```bash
# Install dotenv
npm install -g dotenv-cli

# Run commands with .env
dotenv npm run dev
```
