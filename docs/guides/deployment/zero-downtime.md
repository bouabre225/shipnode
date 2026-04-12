# Zero-Downtime Deployments

ShipNode uses atomic symlink switching to ensure your app is never serving broken code.

## How It Works

```
/var/www/myapp/
├── releases/
│   ├── 20260408120000/    ← previous release
│   └── 20260408143022/    ← new release
├── current -> releases/20260408143022/  ← atomic symlink switch
└── shared/
    └── .env
```

### Deployment Sequence

```
 1. Acquire lock (.deploy.lock)
 2. Create release directory
 3. rsync files to server
 4. Link shared/.env to release
 5. Install dependencies (npm install)
 6. Build (npm run build)
 7. Run pre-deploy hook
 8. Atomic symlink switch (current → new release)
 9. Reload PM2 gracefully
10. Health check (GET /health)
11. Record release metadata
12. Run post-deploy hook
13. Cleanup old releases (keep last 5)
14. Release lock
```

### Atomic Symlink Switch

The critical step:

```bash
ln -sfn /var/www/myapp/releases/20260408143022 /var/www/myapp/current
```

This is atomic at the filesystem level - there's no moment where `current` points to a non-existent directory.

## Automatic Rollback

If the health check fails:

1. Symlink switches back to previous release
2. PM2 reloads the previous version
3. Failed deployment is recorded
4. You can investigate with `shipnode logs`

### Configuration

```bash
ZERO_DOWNTIME=true           # Enable (default: true)
KEEP_RELEASES=5             # Old releases to keep
HEALTH_CHECK_RETRIES=3      # Attempts before rollback
```

## Why Not Blue-Green?

Blue-green requires two full server environments. ShipNode's symlink approach:
- Works on a single server
- Minimal disk usage
- Instant switching
- No complex networking

## Directory Structure

```
/var/www/myapp/
├── current -> releases/20260408143022/
├── releases/
│   ├── 20260408120000/
│   └── 20260408143022/
├── shared/
│   └── .env                              ← persistent across releases
└── .shipnode/
    ├── releases.json                     ← deployment history
    └── deploy.lock                       ← prevents concurrent deploys
```

## Release History

Every deployment records metadata:

```json
{
  "timestamp": "20260408143022",
  "date": "2026-04-08T14:30:22Z",
  "status": "success",
  "duration_seconds": 45,
  "commit": "abc1234",
  "previous_release": "20260408120000",
  "health_check": {
    "passed": true,
    "attempts": 1,
    "response_time_ms": 23
  }
}
```

View releases:

```bash
shipnode releases
```
