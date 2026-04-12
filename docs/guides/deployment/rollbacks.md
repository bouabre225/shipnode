# Rollbacks

Revert to a previous release instantly.

## Rollback Commands

```bash
shipnode rollback           # previous release
shipnode rollback 2         # 2 releases back
shipnode rollback 20260408120000  # specific release
```

## When to Rollback

- Health check fails after deployment
- Application crashes or behaves incorrectly
- Performance issues introduced by new code

## How Rollback Works

```bash
1. Symlink switches to previous release
2. PM2 gracefully reloads
3. Deployment recorded as "rollback"
```

Rollback is instant - no re-build, no re-deploy, just symlink switch.

## View Available Releases

```bash
shipnode releases
```

Output:

```
RELEASES
──────────────────────────────────────
20260408143022  Current   2 hours ago  ✓ success
20260408120000  Previous  5 hours ago  ✓ success
20260407150000           1 day ago      ✓ success
20260406120000           2 days ago     ✓ success
```

## Automatic Rollback

ShipNode automatically rolls back if health check fails:

```
Deployment started...
[✓] Files synced
[✓] Dependencies installed
[✓] Build complete
[✓] Symlink switched
[✓] PM2 reloaded
[✗] Health check failed (3 retries)
[→] Rolling back to previous release...
[✓] Rollback complete
```

## Manual vs Automatic

| Scenario | Action |
|----------|--------|
| Health check fails | Automatic rollback |
| Bug discovered later | `shipnode rollback` |
| Performance regression | `shipnode rollback` |
| Need specific old version | `shipnode rollback <timestamp>` |

## Keeping Releases

Configure how many releases to keep:

```bash
KEEP_RELEASES=5  # default
```

Releases older than this are cleaned up after each deployment.

## Rollback and Database

Rollback only affects application code, not data:
- Database migrations are **not** rolled back
- If migration causes issues, fix with a new migration
- Consider using `PRE_DEPLOY_SCRIPT` to backup before migrations
